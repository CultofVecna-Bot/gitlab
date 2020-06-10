# frozen_string_literal: true

module Gitlab
  module Ci
    ##
    # Ci::Features is a class that aggregates all CI/CD feature flags in one place.
    #
    module Features
      def self.artifacts_exclude_enabled?
        ::Feature.enabled?(:ci_artifacts_exclude, default_enabled: true)
      end

      def self.ensure_scheduling_type_enabled?
        ::Feature.enabled?(:ci_ensure_scheduling_type, default_enabled: true)
      end

      def self.job_heartbeats_runner?(project)
        ::Feature.enabled?(:ci_job_heartbeats_runner, project, default_enabled: true)
      end

      def self.instance_level_variables_limit_enabled?
        ::Feature.enabled?(:ci_instance_level_variables_limit, default_enabled: true)
      end

      def self.pipeline_fixed_notifications?
        ::Feature.enabled?(:ci_pipeline_fixed_notifications)
      end
    end
  end
end
