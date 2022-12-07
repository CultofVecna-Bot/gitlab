# frozen_string_literal: true

module Gitlab
  module Database
    class TablesSortedByForeignKeys
      include TSort

      def initialize(connection, tables)
        @connection = connection
        @tables = tables
      end

      def execute
        strongly_connected_components
      end

      private

      def tsort_each_node(&block)
        tables_dependencies.each_key(&block)
      end

      def tsort_each_child(node, &block)
        tables_dependencies[node].each(&block)
      end

      # it maps the tables to the tables that depend on it
      def tables_dependencies
        @tables.to_h do |table_name|
          [table_name, all_foreign_keys[table_name]]
        end
      end

      def all_foreign_keys
        @all_foreign_keys ||= @tables.each_with_object(Hash.new { |h, k| h[k] = [] }) do |table, hash|
          foreign_keys_for(table).each do |fk|
            hash[fk.to_table] << table
          end
        end
      end

      def foreign_keys_for(table)
        # Detached partitions like gitlab_partitions_dynamic._test_gitlab_partition_20220101
        # store their foreign keys in the public schema.
        #
        # See spec/lib/gitlab/database/tables_sorted_by_foreign_keys_spec.rb
        # for an example
        name = ActiveRecord::ConnectionAdapters::PostgreSQL::Utils.extract_schema_qualified_name(table)

        if name.schema == ::Gitlab::Database::DYNAMIC_PARTITIONS_SCHEMA.to_s
          @connection.foreign_keys(name.identifier)
        else
          @connection.foreign_keys(table)
        end
      end
    end
  end
end
