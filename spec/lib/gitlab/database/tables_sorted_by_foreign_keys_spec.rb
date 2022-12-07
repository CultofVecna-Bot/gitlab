# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Database::TablesSortedByForeignKeys do
  let(:connection) { ApplicationRecord.connection }
  let(:tables) do
    %w[_test_gitlab_main_items _test_gitlab_main_references _test_gitlab_partition_parent
       gitlab_partitions_dynamic._test_gitlab_partition_20220101]
  end

  subject do
    described_class.new(connection, tables).execute
  end

  before do
    statement = <<~SQL
      CREATE TABLE _test_gitlab_main_items (id serial NOT NULL PRIMARY KEY);

      CREATE TABLE _test_gitlab_main_references (
        id serial NOT NULL PRIMARY KEY,
        item_id BIGINT NOT NULL,
        CONSTRAINT fk_constrained_1 FOREIGN KEY(item_id) REFERENCES _test_gitlab_main_items(id)
      );

      CREATE TABLE _test_gitlab_partition_parent (
        id bigserial not null,
        created_at timestamptz not null,
        item_id BIGINT NOT NULL,
        primary key (id, created_at),
        CONSTRAINT fk_constrained_1 FOREIGN KEY(item_id) REFERENCES _test_gitlab_main_items(id)
      ) PARTITION BY RANGE(created_at);

      CREATE TABLE gitlab_partitions_dynamic._test_gitlab_partition_20220101
      PARTITION OF _test_gitlab_partition_parent
      FOR VALUES FROM ('20220101') TO ('20220131');

      ALTER TABLE _test_gitlab_partition_parent DETACH PARTITION gitlab_partitions_dynamic._test_gitlab_partition_20220101;
    SQL
    connection.execute(statement)
  end

  describe '#execute' do
    it 'returns the tables sorted by the foreign keys dependency' do
      expect(subject).to eq(
        [
          ['_test_gitlab_main_references'],
          ['_test_gitlab_partition_parent'],
          ['gitlab_partitions_dynamic._test_gitlab_partition_20220101'],
          ['_test_gitlab_main_items']
        ])
    end

    it 'returns both tables together if they are strongly connected' do
      statement = <<~SQL
        ALTER TABLE _test_gitlab_main_items ADD COLUMN reference_id BIGINT
        REFERENCES _test_gitlab_main_references(id)
      SQL
      connection.execute(statement)

      expect(subject).to eq(
        [
          ['_test_gitlab_partition_parent'],
          ['gitlab_partitions_dynamic._test_gitlab_partition_20220101'],
          %w[_test_gitlab_main_items _test_gitlab_main_references]
        ])
    end
  end
end
