# frozen_string_literal: true

class AddProjectIdFkeyForUserProjectCallout < Gitlab::Database::Migration[2.0]
  disable_ddl_transaction!

  def up
    add_concurrent_foreign_key :user_project_callouts, :projects, column: :project_id, on_delete: :cascade
  end

  def down
    with_lock_retries do
      remove_foreign_key :user_project_callouts, column: :project_id
    end
  end
end
