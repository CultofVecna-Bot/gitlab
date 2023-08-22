# frozen_string_literal: true

module Subscriptions
  class AiCompletionResponse < BaseSubscription
    include Gitlab::Graphql::Laziness
    payload_type ::Types::Ai::AiResponseType

    argument :resource_id, Types::GlobalIDType[::Ai::Model],
      required: false,
      description: 'ID of the resource.'

    argument :user_id, ::Types::GlobalIDType[::User],
      required: false,
      description: 'ID of the user.'

    argument :client_subscription_id, ::GraphQL::Types::String,
      required: false,
      description: 'Client generated ID that be subscribed to, to receive a response for the mutation.'

    def update(*_args)
      {
        response_body: object[:content],
        request_id: object[:request_id],
        role: object[:role],
        errors: object[:errors],
        timestamp: object[:timestamp],
        type: object[:type]
      }
    end

    def authorized?(args)
      unauthorized! if current_user.nil? || args[:user_id] != current_user.to_global_id

      if args[:resource_id]
        resource = force(GitlabSchema.find_by_gid(args[:resource_id]))

        # unsubscribe if user cannot read the issuable anymore for any reason,
        # e.g. and issue was set confidential, in the meantime
        unauthorized! unless resource && Ability.allowed?(current_user, :"read_#{resource.to_ability_name}", resource)
      end

      true
    end
  end
end
