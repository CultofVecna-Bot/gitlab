# frozen_string_literal: true

module Ci
  module Runners
    class RegisterRunnerService
      include Gitlab::Utils::StrongMemoize

      def initialize(registration_token, attributes)
        @registration_token = registration_token
        @attributes = attributes
      end

      def execute
        return ServiceResponse.error(message: 'invalid token supplied', http_status: :forbidden) unless attrs_from_token

        unless registration_token_allowed?(attrs_from_token)
          return ServiceResponse.error(
            message: 'runner registration disallowed',
            reason: :runner_registration_disallowed)
        end

        runner = ::Ci::Runner.new(attributes.merge(attrs_from_token))

        Ci::BulkInsertableTags.with_bulk_insert_tags do
          Ci::Runner.transaction do
            if runner.save
              Gitlab::Ci::Tags::BulkInsert.bulk_insert_tags!([runner])
            else
              raise ActiveRecord::Rollback
            end
          end
        end

        ServiceResponse.success(payload: { runner: runner })
      end

      private

      attr_reader :registration_token, :attributes

      def attrs_from_token
        if runner_registration_token_valid?(registration_token)
          # Create shared runner. Requires admin access
          { runner_type: :instance_type }
        elsif runner_registrar_valid?('project') && project = ::Project.find_by_runners_token(registration_token)
          # Create a project runner
          { runner_type: :project_type, projects: [project] }
        elsif runner_registrar_valid?('group') && group = ::Group.find_by_runners_token(registration_token)
          # Create a group runner
          { runner_type: :group_type, groups: [group] }
        end
      end
      strong_memoize_attr :attrs_from_token

      def registration_token_allowed?(attrs)
        case attrs[:runner_type]
        when :group_type
          token_scope.allow_runner_registration_token?
        when :project_type
          token_scope.namespace.allow_runner_registration_token?
        else
          Gitlab::CurrentSettings.allow_runner_registration_token
        end
      end

      def runner_registration_token_valid?(registration_token)
        ActiveSupport::SecurityUtils.secure_compare(registration_token, Gitlab::CurrentSettings.runners_registration_token)
      end

      def runner_registrar_valid?(type)
        Gitlab::CurrentSettings.valid_runner_registrars.include?(type)
      end

      def token_scope
        case attrs_from_token[:runner_type]
        when :project_type
          attrs_from_token[:projects]&.first
        when :group_type
          attrs_from_token[:groups]&.first
          # No scope for instance type
        end
      end
    end
  end
end

Ci::Runners::RegisterRunnerService.prepend_mod
