# frozen_string_literal: true

module Security
  module SecurityOrchestrationPolicies
    class RuleScheduleService < BaseContainerService
      def execute(schedule)
        branches = schedule.applicable_branches(container)
        actions = actions_for(schedule)
        schedule_errors = schedule_scan(actions, branches).select { |service_result| service_result[:status] == :error }

        return ServiceResponse.success if schedule_errors.blank?

        # The use of .pluck here is not for an Active record model but for a hash
        # rubocop: disable CodeReuse/ActiveRecord
        ServiceResponse.error(message: schedule_errors.pluck(:message))
        # rubocop: enable CodeReuse/ActiveRecord
      end

      private

      def actions_for(schedule)
        policy = schedule.policy
        return [] if policy.blank?

        policy[:actions]
      end

      def schedule_scan(actions, branches)
        return [] if actions.blank?

        branches.map do |branch|
          ::Security::SecurityOrchestrationPolicies::CreatePipelineService
            .new(project: container, current_user: current_user, params: { actions: actions, branch: branch })
            .execute
        end
      end
    end
  end
end
