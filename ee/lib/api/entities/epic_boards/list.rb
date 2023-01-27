# frozen_string_literal: true

module API
  module Entities
    module EpicBoards
      class List < Grape::Entity
        expose :id, documentation: { type: 'integer', example: 1 }
        expose :label, using: Entities::LabelBasic
        expose :position, documentation: { type: 'integer', example: 1 }
      end
    end
  end
end
