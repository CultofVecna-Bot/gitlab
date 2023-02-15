# frozen_string_literal: true

class FixPartitionIdsForCiBuildTraceMetadata < Gitlab::Database::Migration[2.1]
  MIGRATION = 'RebalancePartitionId'
  DELAY_INTERVAL = 2.minutes.freeze
  TABLE = :ci_build_trace_metadata
  BATCH_SIZE = 3_000
  SUB_BATCH_SIZE = 300

  restrict_gitlab_migration gitlab_schema: :gitlab_ci

  def up
    return unless Gitlab.com?

    queue_batched_background_migration(
      MIGRATION,
      TABLE,
      :build_id,
      job_interval: DELAY_INTERVAL,
      batch_size: BATCH_SIZE,
      sub_batch_size: SUB_BATCH_SIZE
    )
  end

  def down
    return unless Gitlab.com?

    delete_batched_background_migration(MIGRATION, TABLE, :build_id, [])
  end
end
