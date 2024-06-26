# frozen_string_literal: true

module EE
  module Members
    module Groups
      module CreatorService
        extend ActiveSupport::Concern
        extend ::Gitlab::Utils::Override

        class_methods do
          extend ::Gitlab::Utils::Override

          private

          override :parsed_args
          def parsed_args(args)
            super.merge(ignore_user_limits: args[:ignore_user_limits])
          end
        end

        private

        override :member_attributes
        def member_attributes
          attributes = super.merge(ignore_user_limits: ignore_user_limits)
          top_level_group = source.root_ancestor

          return attributes unless top_level_group.custom_roles_enabled?

          attributes.merge(member_role_id: member_role_id)
        end

        def ignore_user_limits
          args[:ignore_user_limits]
        end

        def member_role_id
          args[:member_role_id]
        end

        override :member_role_too_high?
        def member_role_too_high?
          return false if skip_authorization?

          user_role = max_role

          return false if current_user.can_admin_all_resources?
          return false unless member_attributes[:access_level]

          member_attributes[:access_level] > user_role
        end

        def max_role
          member.group.highest_group_member(current_user)&.access_level
        end
      end
    end
  end
end
