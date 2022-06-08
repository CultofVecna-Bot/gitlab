# frozen_string_literal: true

module Gitlab
  module Ci
    class Config
      module Entry
        ##
        # Entry that represents a Docker image.
        #
        class Image < ::Gitlab::Config::Entry::Node
          include ::Gitlab::Config::Entry::Validatable
          include ::Gitlab::Config::Entry::Attributable
          include ::Gitlab::Config::Entry::Configurable

          ALLOWED_KEYS = %i[name entrypoint ports pull_policy].freeze
          LEGACY_ALLOWED_KEYS = %i[name entrypoint ports].freeze

          validations do
            validates :config, hash_or_string: true
            validates :config, allowed_keys: ALLOWED_KEYS, if: :ci_docker_image_pull_policy_enabled?
            validates :config, allowed_keys: LEGACY_ALLOWED_KEYS, unless: :ci_docker_image_pull_policy_enabled?
            validates :config, disallowed_keys: %i[ports], unless: :with_image_ports?

            validates :name, type: String, presence: true
            validates :entrypoint, array_of_strings: true, allow_nil: true
          end

          entry :ports, Entry::Ports,
            description: 'Ports used to expose the image'

          entry :pull_policy, Entry::PullPolicy,
            description: 'Pull policy for the image'

          attributes :ports, :pull_policy

          def name
            value[:name]
          end

          def entrypoint
            value[:entrypoint]
          end

          def value
            if string?
              { name: @config }
            elsif hash?
              {
                name: @config[:name],
                entrypoint: @config[:entrypoint],
                ports: ports_value,
                pull_policy: (ci_docker_image_pull_policy_enabled? ? pull_policy_value : nil)
              }.compact
            else
              {}
            end
          end

          def with_image_ports?
            opt(:with_image_ports)
          end

          def ci_docker_image_pull_policy_enabled?
            ::Feature.enabled?(:ci_docker_image_pull_policy)
          end

          def skip_config_hash_validation?
            true
          end
        end
      end
    end
  end
end
