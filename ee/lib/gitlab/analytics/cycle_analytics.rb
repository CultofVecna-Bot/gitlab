# frozen_string_literal: true

module Gitlab
  module Analytics
    module CycleAnalytics
      extend Gitlab::Allowable

      def self.licensed?(subject)
        case subject
        when Namespaces::ProjectNamespace
          subject.licensed_feature_available?(:cycle_analytics_for_projects)
        when Group
          subject.licensed_feature_available?(:cycle_analytics_for_groups)
        else
          false
        end
      end

      def self.allowed?(user, subject)
        case subject
        when Namespaces::ProjectNamespace
          can?(user, :read_cycle_analytics, subject.project)
        when Group
          can?(user, :read_group_cycle_analytics, subject)
        else
          false
        end
      end
    end
  end
end
