# frozen_string_literal: true

module IncidentManagement
  module TimelineEvents
    # @param timeline_event [IncidentManagement::TimelineEvent]
    # @param user [User]
    # @param params [Hash]
    # @option params [string] note
    # @option params [datetime] occurred_at
    class UpdateService < TimelineEvents::BaseService
      VALIDATION_CONTEXT = :user_input

      def initialize(timeline_event, user, params)
        @timeline_event = timeline_event
        @incident = timeline_event.incident
        @user = user
        @note = params[:note]
        @occurred_at = params[:occurred_at]
        @validation_context = VALIDATION_CONTEXT
        @timeline_event_tags = params[:timeline_event_tag_names]
      end

      def execute
        return error_no_permissions unless allowed?

        unless timeline_event_tags.nil?
          tags_to_remove, tags_to_add = compute_tag_updates
          defined_tags = timeline_event
                          .project
                          .incident_management_timeline_event_tags
                          .by_names(tags_to_add)

          non_existing_tags = validate_tags(tags_to_add, defined_tags)

          return error("#{_("Following tags don't exist")}: #{non_existing_tags}") unless non_existing_tags.empty?
        end

        begin
          timeline_event_saved = update_timeline_event_and_event_tags(tags_to_add, tags_to_remove, defined_tags)
        rescue ActiveRecord::RecordInvalid
          error_in_save(timeline_event)
        end

        if timeline_event_saved
          add_system_note(timeline_event)

          track_usage_event(:incident_management_timeline_event_edited, user.id)
          success(timeline_event)
        else
          error_in_save(timeline_event)
        end
      end

      private

      attr_reader :timeline_event, :incident, :user, :note, :occurred_at, :validation_context, :timeline_event_tags

      def update_timeline_event_and_event_tags(tags_to_add, tags_to_remove, defined_tags)
        ApplicationRecord.transaction do
          update_timeline_event_tags(tags_to_add, tags_to_remove, defined_tags) unless timeline_event_tags.nil?

          timeline_event.assign_attributes(update_params)

          timeline_event.save!(context: validation_context)
        end
      end

      def update_params
        { updated_by_user: user, note: note, occurred_at: occurred_at }.compact
      end

      def add_system_note(timeline_event)
        changes = was_changed(timeline_event)
        return if changes == :none

        SystemNoteService.edit_timeline_event(timeline_event, user, was_changed: changes)
      end

      def was_changed(timeline_event)
        changes = timeline_event.previous_changes
        occurred_at_changed = changes.key?('occurred_at')
        note_changed = changes.key?('note')

        return :occurred_at_and_note if occurred_at_changed && note_changed
        return :occurred_at if occurred_at_changed
        return :note if note_changed

        :none
      end

      def compute_tag_updates
        tag_updates = timeline_event_tags.map(&:downcase)
        already_assigned_tags = timeline_event.timeline_event_tags.pluck_names.map(&:downcase)

        tags_to_remove = already_assigned_tags - tag_updates
        tags_to_add = tag_updates - already_assigned_tags

        [tags_to_remove, tags_to_add]
      end

      def update_timeline_event_tags(tags_to_add, tags_to_remove, defined_tags)
        remove_tag_links(tags_to_remove) if tags_to_remove.any?
        create_tag_links(tags_to_add, defined_tags) if tags_to_add.any?
      end

      def remove_tag_links(tags_to_remove_names)
        tags_to_remove_ids = timeline_event.timeline_event_tags.by_names(tags_to_remove_names).tag_ids

        timeline_event
          .timeline_event_tag_links
          .by_tag_ids(tags_to_remove_ids).delete_all
      end

      def create_tag_links(tags_to_add_names, defined_tags)
        tags_to_add_ids = defined_tags.tag_ids

        tag_links = tags_to_add_ids.map do |tag_id|
          {
            timeline_event_id: timeline_event.id,
            timeline_event_tag_id: tag_id,
            created_at: DateTime.current
          }
        end

        IncidentManagement::TimelineEventTagLink.insert_all(tag_links) if tag_links.any?
      end

      def validate_tags(tags_to_add, defined_tags)
        defined_tags = defined_tags.pluck_names.map(&:downcase)

        tags_to_add - defined_tags
      end

      def allowed?
        user&.can?(:edit_incident_management_timeline_event, timeline_event)
      end
    end
  end
end
