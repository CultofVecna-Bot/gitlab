# frozen_string_literal: true

module GitlabSubscriptions
  module AddOnPurchases
    class ScheduleBulkRefreshUserAssignmentsWorker
      include ApplicationWorker
      include CronjobQueue # rubocop:disable Scalability/CronWorkerContext

      feature_category :seat_cost_management
      data_consistency :sticky
      urgency :low

      idempotent!

      def perform
        return unless Feature.enabled?(:hamilton_seat_management)

        return unless ::Gitlab::CurrentSettings.should_check_namespace_plan?

        GitlabSubscriptions::AddOnPurchases::BulkRefreshUserAssignmentsWorker.perform_with_capacity
      end
    end
  end
end
