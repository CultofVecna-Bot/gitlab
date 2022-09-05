# frozen_string_literal: true

module Gitlab
  module QuickActions
    class TimelineTextAndDateTimeSeparator
      DATETIME_REGEX = %r{(\d{2,4}[/\-.]\d{1,2}[/\-.]\d{1,2} \d{1,2}:\d{2})}.freeze
      TIME_REGEX = %r{(\d{1,2}:\d{2})}.freeze

      def initialize(timeline_event_arg)
        @timeline_event_arg = timeline_event_arg
        @timeline_text = timeline_event_arg.split('|')[0]&.strip
        @timeline_date_string = get_raw_date_string
      end

      def execute
        return if @timeline_event_arg.blank?
        return [@timeline_text, get_current_date_time] unless date_time_present?
        return unless valid_date?

        [get_text, get_actual_date_time]
      end

      private

      def get_text
        @timeline_event_arg.split('|')[0]&.strip
      end

      def get_raw_date_string
        @timeline_event_arg.split('|')[1]&.strip
      end

      def get_current_date_time
        DateTime.current.strftime("%Y-%m-%d %H:%M:00 UTC")
      end

      def get_actual_date_time
        DateTime.parse(@timeline_date_string)
      end

      def date_time_present?
        DATETIME_REGEX =~ @timeline_date_string || TIME_REGEX =~ @timeline_date_string
      end

      def valid_date?
        get_actual_date_time
      rescue StandardError
        nil
      end
    end
  end
end
