# frozen_string_literal: true

module UserCalloutsHelper
  GKE_CLUSTER_INTEGRATION = 'gke_cluster_integration'
  GCP_SIGNUP_OFFER = 'gcp_signup_offer'
  SUGGEST_POPOVER_DISMISSED = 'suggest_popover_dismissed'
  TABS_POSITION_HIGHLIGHT = 'tabs_position_highlight'
  CUSTOMIZE_HOMEPAGE = 'customize_homepage'
  FEATURE_FLAGS_NEW_VERSION = 'feature_flags_new_version'
  REGISTRATION_ENABLED_CALLOUT = 'registration_enabled_callout'
  UNFINISHED_TAG_CLEANUP_CALLOUT = 'unfinished_tag_cleanup_callout'
  INVITE_MEMBERS_BANNER = 'invite_members_banner'
  SECURITY_NEWSLETTER_CALLOUT = 'security_newsletter_callout'

  def show_gke_cluster_integration_callout?(project)
    active_nav_link?(controller: sidebar_operations_paths) &&
      can?(current_user, :create_cluster, project) &&
      !user_dismissed?(GKE_CLUSTER_INTEGRATION)
  end

  def show_gcp_signup_offer?
    !user_dismissed?(GCP_SIGNUP_OFFER)
  end

  def render_flash_user_callout(flash_type, message, feature_name)
    render 'shared/flash_user_callout', flash_type: flash_type, message: message, feature_name: feature_name
  end

  def render_dashboard_ultimate_trial(user)
  end

  def render_two_factor_auth_recovery_settings_check
  end

  def show_suggest_popover?
    !user_dismissed?(SUGGEST_POPOVER_DISMISSED)
  end

  def show_customize_homepage_banner?
    current_user.default_dashboard? && !user_dismissed?(CUSTOMIZE_HOMEPAGE)
  end

  def show_feature_flags_new_version?
    !user_dismissed?(FEATURE_FLAGS_NEW_VERSION)
  end

  def show_unfinished_tag_cleanup_callout?
    !user_dismissed?(UNFINISHED_TAG_CLEANUP_CALLOUT)
  end

  def show_registration_enabled_user_callout?
    !Gitlab.com? &&
    current_user&.admin? &&
    signup_enabled? &&
    !user_dismissed?(REGISTRATION_ENABLED_CALLOUT)
  end

  def dismiss_two_factor_auth_recovery_settings_check
  end

  def show_invite_banner?(group)
    Ability.allowed?(current_user, :admin_group, group) &&
      !just_created? &&
      !user_dismissed_for_group(INVITE_MEMBERS_BANNER, group) &&
      !multiple_members?(group)
  end

  def show_security_newsletter_user_callout?
    current_user&.admin? &&
    !user_dismissed?(SECURITY_NEWSLETTER_CALLOUT)
  end

  private

  def user_dismissed?(feature_name, ignore_dismissal_earlier_than = nil)
    return false unless current_user

    current_user.dismissed_callout?(feature_name: feature_name, ignore_dismissal_earlier_than: ignore_dismissal_earlier_than)
  end

  def user_dismissed_for_group(feature_name, group, ignore_dismissal_earlier_than = nil)
    return false unless current_user

    set_dismissed_from_cookie(group)

    current_user.dismissed_callout_for_group?(feature_name: feature_name,
                                              group: group,
                                              ignore_dismissal_earlier_than: ignore_dismissal_earlier_than)
  end

  def set_dismissed_from_cookie(group)
    # bridge function for one milestone to try and not annoy users who might have already dismissed this alert
    # remove in 14.4 or 14.5? https://gitlab.com/gitlab-org/gitlab/-/issues/340322
    dismissed_key = "invite_#{group.id}_#{current_user.id}"

    if cookies[dismissed_key].present?
      params = {
        feature_name: INVITE_MEMBERS_BANNER,
        group_id: group.id
      }

      Users::DismissGroupCalloutService.new(
        container: nil, current_user: current_user, params: params
      ).execute

      cookies.delete dismissed_key
    end
  end

  def just_created?
    flash[:notice]&.include?('successfully created')
  end

  def multiple_members?(group)
    group.member_count > 1 || group.members_with_parents.count > 1
  end
end

UserCalloutsHelper.prepend_mod
