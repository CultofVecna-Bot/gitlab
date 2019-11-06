# frozen_string_literal: true

module QA
  module Runtime
    module Feature
      extend self
      extend Support::Api

      SetFeatureError = Class.new(RuntimeError)
      AuthorizationError = Class.new(RuntimeError)

      def enable(key)
        QA::Runtime::Logger.info("Enabling feature: #{key}")
        set_feature(key, true)
      end

      def disable(key)
        QA::Runtime::Logger.info("Disabling feature: #{key}")
        set_feature(key, false)
      end

      def enabled?(key)
        feature = JSON.parse(get_features).find { |flag| flag["name"] == key }
        feature && feature["state"] == "on"
      end

      private

      def api_client
        @api_client ||= begin
          if Runtime::Env.admin_personal_access_token
            Runtime::API::Client.new(:gitlab, personal_access_token: Runtime::Env.admin_personal_access_token)
          else
            user = Resource::User.fabricate_via_api! do |user|
              user.username = Runtime::User.admin_username
              user.password = Runtime::User.admin_password
            end

            unless user.admin?
              raise AuthorizationError, "Administrator access is required to enable/disable feature flags. User '#{user.username}' is not an administrator."
            end

            Runtime::API::Client.new(:gitlab, user: user)
          end
        end
      end

      def set_feature(key, value)
        request = Runtime::API::Request.new(api_client, "/features/#{key}")
        response = post(request.url, { value: value })
        unless response.code == QA::Support::Api::HTTP_STATUS_CREATED
          raise SetFeatureError, "Setting feature flag #{key} to #{value} failed with `#{response}`."
        end
      end

      def get_features
        request = Runtime::API::Request.new(api_client, "/features")
        response = get(request.url)
        response.body
      end
    end
  end
end
