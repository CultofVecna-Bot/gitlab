# frozen_string_literal: true

module Gitlab
  module Metrics
    module Dashboard
      # Responsible for processesing a dashboard hash, inserting
      # relevant DB records & sorting for proper rendering in
      # the UI. These includes shared metric info, custom metrics
      # info, and alerts (only in EE).
      class Processor
        SEQUENCE = [
          Stages::CommonMetricsInserter,
          Stages::ProjectMetricsInserter,
          Stages::Sorter
        ].freeze

        def initialize(project, environment, dashboard)
          @project = project
          @environment = environment
          @dashboard = dashboard
        end

        # Returns a new dashboard hash with the results of
        # running transforms on the dashboard.
        def process
          @dashboard.deep_symbolize_keys.tap do |dashboard|
            sequence.each do |stage|
              stage.new(@project, @environment, dashboard).transform!
            end
          end
        end

        private

        def sequence
          SEQUENCE
        end
      end
    end
  end
end

Gitlab::Metrics::Dashboard::Processor.prepend EE::Gitlab::Metrics::Dashboard::Processor
