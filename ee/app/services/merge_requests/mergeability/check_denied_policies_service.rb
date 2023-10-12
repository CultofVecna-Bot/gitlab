# frozen_string_literal: true

module MergeRequests
  module Mergeability
    class CheckDeniedPoliciesService < CheckBaseService
      def self.failure_reason
        :policies_denied
      end

      def execute
        if merge_request.has_denied_policies?
          failure(reason: failure_reason)
        else
          success
        end
      end

      def skip?
        false
      end

      def cacheable?
        false
      end
    end
  end
end
