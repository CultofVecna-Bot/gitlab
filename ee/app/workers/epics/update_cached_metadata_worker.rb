# frozen_string_literal: true

module Epics
  class UpdateCachedMetadataWorker
    include ApplicationWorker

    BATCH_SIZE = 100

    data_consistency :delayed
    idempotent!
    queue_namespace :epics
    feature_category :portfolio_management

    def perform(ids)
      ::Epic.id_in(ids).find_each do |epic|
        update_epic(epic)
      end
    end

    private

    def update_epic(epic)
      total_sums = epic.total_issue_weight_and_count
      epic.assign_attributes(total_sums)

      log_extra_metadata_on_done(:epic_id, epic.id)
      log_extra_metadata_on_done(:epic_iid, epic.iid)
      log_extra_metadata_on_done(:changed, epic.changed?)
      log_extra_metadata_on_done(:total_opened_issue_count, epic.total_opened_issue_count)
      log_extra_metadata_on_done(:total_closed_issue_count, epic.total_closed_issue_count)
      log_extra_metadata_on_done(:total_opened_issue_weight, epic.total_opened_issue_weight)
      log_extra_metadata_on_done(:total_closed_issue_weight, epic.total_closed_issue_weight)

      epic.save!(touch: false)
    end
  end
end
