# frozen_string_literal: true

module Elastic
  class ProcessInitialBookkeepingService < Elastic::ProcessBookkeepingService
    INDEXED_PROJECT_ASSOCIATIONS = [
      :issues,
      :merge_requests,
      :snippets,
      :notes,
      :milestones
    ].freeze

    class << self
      def redis_set_key(shard_number)
        "elastic:bulk:initial:#{shard_number}:zset"
      end

      def redis_score_key(shard_number)
        "elastic:bulk:initial:#{shard_number}:score"
      end

      def backfill_projects!(*projects)
        track!(*projects)

        projects.each do |project|
          raise ArgumentError, 'This method only accepts Projects' unless project.is_a?(Project)

          next unless project.maintaining_indexed_associations?

          maintain_indexed_associations(project, INDEXED_PROJECT_ASSOCIATIONS)

          ElasticCommitIndexerWorker.perform_async(project.id, false, { force: true })
          ElasticWikiIndexerWorker.perform_async(project.id, project.class.name, { force: true })
        end
      end
    end
  end
end
