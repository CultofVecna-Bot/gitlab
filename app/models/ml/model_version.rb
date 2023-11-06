# frozen_string_literal: true

module Ml
  class ModelVersion < ApplicationRecord
    include Presentable

    validates :project, :model, presence: true

    validates :version,
      format: Gitlab::Regex.semver_regex,
      uniqueness: { scope: [:project, :model_id] },
      presence: true,
      length: { maximum: 255 }

    validates :description,
      length: { maximum: 500 }

    validate :valid_model?, :valid_package?

    belongs_to :model, class_name: 'Ml::Model'
    belongs_to :project
    belongs_to :package, class_name: 'Packages::MlModel::Package', optional: true
    has_one :candidate, class_name: 'Ml::Candidate'

    delegate :name, to: :model

    scope :order_by_model_id_id_desc, -> { order('model_id, id DESC') }
    scope :latest_by_model, -> { order_by_model_id_id_desc.select('DISTINCT ON (model_id) *') }

    class << self
      def find_or_create!(model, version, package, description)
        create_with(package: package, description: description)
          .find_or_create_by!(project: model.project, model: model, version: version)
      end

      def by_project_id_and_id(project_id, id)
        find_by(project_id: project_id, id: id)
      end

      def by_project_id_name_and_version(project_id, name, version)
        joins(:model).find_by(model: { name: name, project_id: project_id }, project_id: project_id, version: version)
      end
    end

    private

    def valid_model?
      return unless model

      errors.add(:model, 'model project must be the same') unless model.project_id == project_id
    end

    def valid_package?
      return unless package

      errors.add(:package, 'package must be ml_model') unless package.ml_model?
      errors.add(:package, 'package name must be the same') unless package.name == name
      errors.add(:package, 'package version must be the same') unless package.version == version
      errors.add(:package, 'package project must be the same') unless package.project_id == project_id
    end
  end
end
