# frozen_string_literal: true

module ProductAnalytics
  class InitializeStackService < BaseContainerService
    def execute
      return unless ::Feature.enabled?(:cube_api_proxy, container.group)

      ::ProductAnalytics::InitializeAnalyticsWorker.perform_async(container.id)
    end
  end
end
