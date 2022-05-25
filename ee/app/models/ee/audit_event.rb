# frozen_string_literal: true

module EE
  module AuditEvent
    extend ActiveSupport::Concern
    extend ::Gitlab::Utils::Override

    TRUNCATED_FIELDS = {
      entity_path: 5_500,
      target_details: 5_500
    }.freeze

    prepended do
      scope :by_entity, -> (entity_type, entity_id) { by_entity_type(entity_type).by_entity_id(entity_id) }

      before_validation :truncate_fields
    end

    def entity
      lazy_entity
    end

    def entity_path
      super || details[:entity_path]
    end

    def present
      AuditEventPresenter.new(self)
    end

    def target_type
      super || details[:target_type]
    end

    def target_id
      details[:target_id]
    end

    def target_details
      super || details[:target_details]
    end

    def ip_address
      super&.to_s || details[:ip_address]
    end

    def lazy_entity
      BatchLoader.for(entity_id)
        .batch(
          key: entity_type, default_value: ::Gitlab::Audit::NullEntity.new
        ) do |ids, loader, args|
          model = Object.const_get(args[:key], false)
          model.where(id: ids).find_each { |record| loader.call(record.id, record) }
        end
    end

    def stream_to_external_destinations(use_json: false, event_name: 'audit_operation')
      return unless can_stream_to_external_destination?

      perform_params = use_json ? [event_name, nil, self.to_json] : [event_name, id, nil]
      AuditEvents::AuditEventStreamingWorker.perform_async(*perform_params)
    end

    def entity_is_group_or_project?
      %w(Group Project).include?(entity_type)
    end

    private

    def can_stream_to_external_destination?
      return false if entity.nil?

      group = group_entity
      return false if group.nil?
      return false unless group.licensed_feature_available?(:external_audit_events)

      group.external_audit_event_destinations.exists?
    end

    def group_entity
      case entity_type
      when 'Group'
        entity
      when 'Project'
        # Project events should be sent to the root ancestor's streaming destinations
        # Projects without a group root ancestor should be ignored.
        entity.group&.root_ancestor
      else
        nil
      end
    end

    def truncate_fields
      TRUNCATED_FIELDS.each do |name, limit|
        original = self[name] || self.details[name]
        next unless original

        self[name] = self.details[name] = String(original).truncate(limit)
      end
    end
  end
end
