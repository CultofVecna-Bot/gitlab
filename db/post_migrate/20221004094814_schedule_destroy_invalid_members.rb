# frozen_string_literal: true
class ScheduleDestroyInvalidMembers < Gitlab::Database::Migration[2.0]
  MIGRATION = 'DestroyInvalidMembers'
  DELAY_INTERVAL = 2.minutes
  BATCH_SIZE = 1_000
  MAX_BATCH_SIZE = 10_000
  SUB_BATCH_SIZE = 200

  restrict_gitlab_migration gitlab_schema: :gitlab_main

  def up
    queue_batched_background_migration(
      MIGRATION,
      :members,
      :id,
      job_interval: DELAY_INTERVAL,
      batch_size: BATCH_SIZE,
      max_batch_size: MAX_BATCH_SIZE,
      sub_batch_size: SUB_BATCH_SIZE,
      gitlab_schema: :gitlab_main
    )
  end

  def down
    delete_batched_background_migration(MIGRATION, :members, :id, [])
  end
end
