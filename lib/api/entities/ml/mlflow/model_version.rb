# frozen_string_literal: true

module API
  module Entities
    module Ml
      module Mlflow
        class ModelVersion < Grape::Entity
          include ::API::Helpers::RelatedResourcesHelpers

          expose :name
          expose :version
          expose :creation_timestamp, documentation: { type: Integer }
          expose :last_updated_timestamp, documentation: { type: Integer }
          expose :user_id
          expose :current_stage
          expose :description
          expose :source
          expose :run_id
          expose :status
          expose :status_message
          expose :metadata
          expose :run_link
          expose :aliases, documentation: { is_array: true, type: String }

          private

          def name
            object.name
          end

          def creation_timestamp
            object.created_at.to_i
          end

          def last_updated_timestamp
            object.updated_at.to_i
          end

          def user_id
            nil
          end

          def current_stage
            "development"
          end

          def description
            object.description.to_s
          end

          def source
            expose_url(Gitlab::Routing.url_helpers.project_ml_model_version_path(
              object.model.project,
              object.model,
              object
            ))
          end

          def run_id
            object.candidate.eid
          end

          def status
            "READY"
          end

          def status_message
            ""
          end

          def metadata
            []
          end

          def run_link
            ""
          end

          def aliases
            []
          end
        end
      end
    end
  end
end
