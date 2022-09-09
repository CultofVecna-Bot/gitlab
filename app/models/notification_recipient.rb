# frozen_string_literal: true

class NotificationRecipient
  include Gitlab::Utils::StrongMemoize

  attr_reader :user, :type, :reason

  def initialize(user, type, opts = {})
    unless NotificationSetting.levels.key?(type) || type == :subscription
      raise ArgumentError, "invalid type: #{type.inspect}"
    end

    @custom_action = opts[:custom_action]
    @acting_user = opts[:acting_user]
    @target = opts[:target]
    @project = opts[:project] || default_project
    @group = opts[:group] || @project&.group
    @user = user
    @type = type
    @reason = opts[:reason]
    @skip_read_ability = opts[:skip_read_ability]
  end

  def notification_setting
    @notification_setting ||= find_notification_setting
  end

  def notification_level
    @notification_level ||= notification_setting&.level&.to_sym
  end

  def notifiable?
    return false unless has_access?
    return false if emails_disabled?
    return false if own_activity?

    # even users with :disabled notifications receive manual subscriptions
    return !unsubscribed? if @type == :subscription

    return false unless suitable_notification_level?
    return false if email_blocked?

    # check this last because it's expensive
    # nobody should receive notifications if they've specifically unsubscribed
    # except if they were mentioned.
    return false if @type != :mention && unsubscribed?

    true
  end

  def suitable_notification_level?
    case notification_level
    when :mention
      @type == :mention
    when :participating
      participating_custom_action? || participating_or_mention?
    when :custom
      custom_enabled? || participating_or_mention?
    when :watch
      !excluded_watcher_action?
    else
      false
    end
  end

  def custom_enabled?
    return false unless @custom_action
    return false unless notification_setting

    notification_setting.event_enabled?(@custom_action) ||
      # fixed_pipeline is a subset of success_pipeline event
      (@custom_action == :fixed_pipeline &&
       notification_setting.event_enabled?(:success_pipeline))
  end

  def unsubscribed?
    subscribable_target = @target.is_a?(Note) ? @target.noteable : @target

    return false unless subscribable_target
    return false unless subscribable_target.respond_to?(:subscriptions)

    subscription = subscribable_target.subscriptions.find { |subscription| subscription.user_id == @user.id }
    subscription && !subscription.subscribed
  end

  def own_activity?
    return false unless @acting_user

    if user == @acting_user
      # if activity was generated by the same user, change reason to :own_activity
      @reason = NotificationReason::OWN_ACTIVITY
      # If the user wants to be notified, we must return `false`
      !@acting_user.notified_of_own_activity?
    else
      false
    end
  end

  def email_blocked?
    return false if Feature.disabled?(:block_emails_with_failures)

    recipient_email = user.notification_email_for(@group)

    Gitlab::ApplicationRateLimiter.peek(:permanent_email_failure, scope: recipient_email) ||
      Gitlab::ApplicationRateLimiter.peek(:temporary_email_failure, scope: recipient_email)
  end

  def has_access?
    DeclarativePolicy.subject_scope do
      break false unless user.can?(:receive_notifications)
      break true if @skip_read_ability

      break false if @target && !user.can?(:read_cross_project)
      break false if @project && !user.can?(:read_project, @project)

      break true unless read_ability
      break true unless DeclarativePolicy.has_policy?(@target)

      user.can?(read_ability, @target)
    end
  end

  def excluded_watcher_action?
    return false unless @type == :watch
    return false unless @custom_action

    NotificationSetting::EXCLUDED_WATCHER_EVENTS.include?(@custom_action)
  end

  private

  # They are disabled if the project or group has disallowed it.
  # No need to check the group if there is already a project
  def emails_disabled?
    @project ? @project.emails_disabled? : @group&.emails_disabled?
  end

  def emails_enabled?
    !emails_disabled?
  end

  def read_ability
    return if @skip_read_ability
    return @read_ability if instance_variable_defined?(:@read_ability)

    @read_ability =
      if @target.is_a?(Ci::Pipeline)
        :read_build # We have build trace in pipeline emails
      elsif default_ability_for_target
        :"read_#{default_ability_for_target}"
      end
  end

  def default_ability_for_target
    @default_ability_for_target ||=
      if @target.respond_to?(:to_ability_name)
        @target.to_ability_name
      elsif @target.class.respond_to?(:model_name)
        @target.class.model_name.name.underscore
      end
  end

  def default_project
    return if @target.nil?
    return @target if @target.is_a?(Project)
    return @target.project if @target.respond_to?(:project)
  end

  def find_notification_setting
    project_setting = @project && user.notification_settings_for(@project)

    return project_setting unless project_setting.nil? || project_setting.global?

    group_setting = closest_non_global_group_notification_setting

    return group_setting unless group_setting.nil?

    user.global_notification_setting
  end

  # Returns the notification_setting of the lowest group in hierarchy with non global level
  def closest_non_global_group_notification_setting
    return unless @group

    @group
      .notification_settings(hierarchy_order: :asc)
      .where(user: user)
      .where.not(level: NotificationSetting.levels[:global])
      .first
  end

  def participating_custom_action?
    %i[failed_pipeline fixed_pipeline moved_project].include?(@custom_action)
  end

  def participating_or_mention?
    %i[participating mention].include?(@type)
  end
end
