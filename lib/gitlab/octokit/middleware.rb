# frozen_string_literal: true

module Gitlab
  module Octokit
    class Middleware
      def initialize(app)
        @app = app
      end

      def call(env)
        Gitlab::UrlBlocker.validate!(env[:url],
          schemes: %w[http https],
          allow_localhost: allow_local_requests?,
          allow_local_network: allow_local_requests?,
          dns_rebind_protection: dns_rebind_protection?
        )

        @app.call(env)
      end

      private

      def allow_local_requests?
        Gitlab::CurrentSettings.allow_local_requests_from_web_hooks_and_services?
      end

      def dns_rebind_protection?
        Gitlab::CurrentSettings.dns_rebinding_protection_enabled?
      end
    end
  end
end
