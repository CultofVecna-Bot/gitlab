# frozen_string_literal: true

module Gitlab
  module Alerting
    class NotificationPayloadParser
      DEFAULT_TITLE = 'New: Incident'

      def initialize(payload)
        @payload = payload.to_h.with_indifferent_access
      end

      def self.call(payload)
        new(payload).call
      end

      def call
        {
          'annotations' => annotations,
          'startsAt' => starts_at
        }.compact
      end

      private

      attr_reader :payload

      def title
        payload[:title].presence || DEFAULT_TITLE
      end

      def annotations
        {
          'title' => title,
          'description' => payload[:description],
          'monitoring_tool' => payload[:monitoring_tool],
          'service' => payload[:service],
          'hosts' => hosts
        }.compact
      end

      def hosts
        payload[:hosts] && Array(payload[:hosts])
      end

      def current_time
        Time.current.change(usec: 0).rfc3339
      end

      def starts_at
        DateTime.parse(payload[:start_time].to_s).rfc3339
      rescue ArgumentError
        current_time
      end
    end
  end
end
