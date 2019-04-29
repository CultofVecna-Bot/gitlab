# frozen_string_literal: true

module Geo
  class AttachmentRegistryFinder < FileRegistryFinder
    def count_syncable
      syncable.count
    end

    def count_synced
      attachments_synced.count
    end

    def count_failed
      attachments_failed.count
    end

    def count_synced_missing_on_primary
      attachments_synced_missing_on_primary.count
    end

    def count_registry
      registries_for_attachments.count
    end

    def syncable
      if use_legacy_queries_for_selective_sync?
        legacy_finder.syncable
      elsif selective_sync?
        attachments.syncable
      else
        Upload.syncable
      end
    end

    # Find limited amount of non replicated attachments.
    #
    # You can pass a list with `except_file_ids:` so you can exclude items you
    # already scheduled but haven't finished and aren't persisted to the database yet
    #
    # TODO: Alternative here is to use some sort of window function with a cursor instead
    #       of simply limiting the query and passing a list of items we don't want
    #
    # @param [Integer] batch_size used to limit the results returned
    # @param [Array<Integer>] except_file_ids ids that will be ignored from the query
    # rubocop: disable CodeReuse/ActiveRecord
    def find_unsynced(batch_size:, except_file_ids: [])
      relation =
        if use_legacy_queries?
          legacy_find_unsynced(except_file_ids: except_file_ids)
        else
          fdw_find_unsynced(except_file_ids: except_file_ids)
        end

      relation.limit(batch_size)
    end
    # rubocop: enable CodeReuse/ActiveRecord

    # rubocop: disable CodeReuse/ActiveRecord
    def find_migrated_local(batch_size:, except_file_ids: [])
      relation =
        if use_legacy_queries?
          legacy_find_migrated_local(except_file_ids: except_file_ids)
        else
          fdw_find_migrated_local(except_file_ids: except_file_ids)
        end

      relation.limit(batch_size)
    end
    # rubocop: enable CodeReuse/ActiveRecord

    # rubocop: disable CodeReuse/ActiveRecord
    def find_retryable_failed_registries(batch_size:, except_file_ids: [])
      Geo::FileRegistry
        .attachments
        .failed
        .retry_due
        .file_id_not_in(except_file_ids)
        .limit(batch_size)
    end
    # rubocop: enable CodeReuse/ActiveRecord

    # rubocop: disable CodeReuse/ActiveRecord
    def find_retryable_synced_missing_on_primary_registries(batch_size:, except_file_ids: [])
      Geo::FileRegistry
        .attachments
        .synced
        .missing_on_primary
        .retry_due
        .file_id_not_in(except_file_ids)
        .limit(batch_size)
    end
    # rubocop: enable CodeReuse/ActiveRecord

    private

    # rubocop:disable CodeReuse/Finder
    def legacy_finder
      @legacy_finder ||= Geo::LegacyAttachmentRegistryFinder.new(current_node: current_node)
    end
    # rubocop:enable CodeReuse/Finder

    def fdw_geo_node
      @fdw_geo_node ||= Geo::Fdw::GeoNode.find(current_node.id)
    end

    def registries_for_attachments
      if use_legacy_queries_for_selective_sync?
        legacy_finder.registries_for_attachments
      else
        attachments
          .inner_join_file_registry
          .merge(Geo::FileRegistry.attachments)
      end
    end

    def attachments_synced
      if use_legacy_queries_for_selective_sync?
        legacy_finder.attachments_synced
      else
        registries_for_attachments
          .syncable
          .merge(Geo::FileRegistry.synced)
      end
    end

    def attachments_failed
      if use_legacy_queries_for_selective_sync?
        legacy_finder.attachments_failed
      else
        registries_for_attachments
          .syncable
          .merge(Geo::FileRegistry.failed)
      end
    end

    def attachments_synced_missing_on_primary
      if use_legacy_queries_for_selective_sync?
        legacy_finder.attachments_synced_missing_on_primary
      else
        registries_for_attachments
          .syncable
          .merge(Geo::FileRegistry.synced)
          .merge(Geo::FileRegistry.missing_on_primary)
      end
    end

    # rubocop: disable CodeReuse/ActiveRecord
    def attachments
      if selective_sync?
        Geo::Fdw::Upload.where(group_uploads.or(project_uploads).or(other_uploads))
      else
        Geo::Fdw::Upload.all
      end
    end
    # rubocop: enable CodeReuse/ActiveRecord

    # rubocop: disable CodeReuse/ActiveRecord
    def group_uploads
      namespace_ids =
        if current_node.selective_sync_by_namespaces?
          Gitlab::ObjectHierarchy.new(fdw_geo_node.namespaces).base_and_descendants.select(:id)
        elsif current_node.selective_sync_by_shards?
          leaf_groups = Geo::Fdw::Namespace.where(id: fdw_geo_node.projects.select(:namespace_id))
          Gitlab::ObjectHierarchy.new(leaf_groups).base_and_ancestors.select(:id)
        else
          Namespace.none
        end

      # This query was intentionally converted to a raw one to get it work in Rails 5.0.
      # In Rails 5.0 and 5.1 there's a bug: https://github.com/rails/arel/issues/531
      # Please convert it back when on rails 5.2 as it works again as expected since 5.2.
      namespace_ids_in_sql = Arel::Nodes::SqlLiteral.new("#{fdw_upload_table.name}.#{fdw_upload_table[:model_id].name} IN (#{namespace_ids.to_sql})")

      fdw_upload_table[:model_type].eq('Namespace').and(namespace_ids_in_sql)
    end
    # rubocop: enable CodeReuse/ActiveRecord

    def project_uploads
      project_ids = fdw_geo_node.projects.select(:id)

      # This query was intentionally converted to a raw one to get it work in Rails 5.0.
      # In Rails 5.0 and 5.1 there's a bug: https://github.com/rails/arel/issues/531
      # Please convert it back when on rails 5.2 as it works again as expected since 5.2.
      project_ids_in_sql = Arel::Nodes::SqlLiteral.new("#{fdw_upload_table.name}.#{fdw_upload_table[:model_id].name} IN (#{project_ids.to_sql})")

      fdw_upload_table[:model_type].eq('Project').and(project_ids_in_sql)
    end

    def other_uploads
      fdw_upload_table[:model_type].not_in(%w[Namespace Project])
    end

    def fdw_upload_table
      Geo::Fdw::Upload.arel_table
    end

    def fdw_find_unsynced(except_file_ids:)
      attachments
        .missing_file_registry
        .syncable
        .id_not_in(except_file_ids)
    end

    def fdw_find_migrated_local(except_file_ids:)
      attachments
        .inner_join_file_registry
        .with_files_stored_remotely
        .merge(Geo::FileRegistry.attachments)
        .id_not_in(except_file_ids)
    end

    def legacy_find_unsynced(except_file_ids:)
      registry_file_ids = Geo::FileRegistry.attachments.pluck_file_key | except_file_ids

      legacy_left_outer_join_registry_ids(
        syncable,
        registry_file_ids,
        Upload
      )
    end

    def legacy_find_migrated_local(except_file_ids:)
      registry_file_ids = Geo::FileRegistry.attachments.pluck_file_key - except_file_ids

      legacy_inner_join_registry_ids(
        legacy_finder.attachments.with_files_stored_remotely,
        registry_file_ids,
        Upload
      )
    end
  end
end
