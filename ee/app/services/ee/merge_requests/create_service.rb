# frozen_string_literal: true

module EE
  module MergeRequests
    module CreateService
      extend ::Gitlab::Utils::Override

      override :after_create
      def after_create(issuable)
        super

        ::MergeRequests::SyncCodeOwnerApprovalRulesWorker.perform_async(issuable.id)
        ::MergeRequests::SyncReportApproverApprovalRules.new(issuable, current_user).execute

        ::MergeRequests::UpdateBlocksService
          .new(issuable, current_user, blocking_merge_requests_params)
          .execute

        trigger_suggested_reviewers_fetch(issuable)
        stream_audit_event(issuable)
      end

      private

      def trigger_suggested_reviewers_fetch(issuable)
        return unless project.suggested_reviewers_available?
        return unless issuable.can_suggest_reviewers?

        ::MergeRequests::FetchSuggestedReviewersWorker.perform_async(issuable.id)
      end

      def stream_audit_event(merge_request)
        audit_context = {
          name: 'merge_request_create',
          stream_only: true,
          author: current_user,
          scope: merge_request.project,
          target: merge_request,
          message: 'Added merge request'
        }

        ::Gitlab::Audit::Auditor.audit(audit_context)
      end
    end
  end
end
