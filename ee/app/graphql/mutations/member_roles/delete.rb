# frozen_string_literal: true

module Mutations
  module MemberRoles
    class Delete < ::Mutations::BaseMutation
      graphql_name 'MemberRoleDelete'

      authorize :admin_member_role

      argument :id, ::Types::GlobalIDType[::MemberRole],
        required: true,
        description: 'ID of the member role to delete.'

      field :member_role, ::Types::MemberRoles::MemberRoleType,
        description: 'Deleted member role.', null: true

      def resolve(id:)
        member_role = authorized_find!(id: id)

        response = ::MemberRoles::DeleteService
          .new(member_role.namespace, current_user)
          .execute(member_role)

        {
          member_role: response.payload[:member_role],
          errors: response.errors
        }
      end
    end
  end
end
