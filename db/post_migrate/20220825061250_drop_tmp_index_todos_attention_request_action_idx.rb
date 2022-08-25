# frozen_string_literal: true

class DropTmpIndexTodosAttentionRequestActionIdx < Gitlab::Database::Migration[2.0]
  INDEX_NAME = "tmp_index_todos_attention_request_action"
  ATTENTION_REQUESTED = 10

  disable_ddl_transaction!

  def up
    remove_concurrent_index_by_name :todos, INDEX_NAME
  end

  def down
    add_concurrent_index :todos, [:id],
      where: "action = #{ATTENTION_REQUESTED}",
      name: INDEX_NAME
  end
end
