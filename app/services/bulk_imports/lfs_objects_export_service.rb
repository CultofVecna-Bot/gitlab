# frozen_string_literal: true

module BulkImports
  class LfsObjectsExportService
    include Gitlab::ImportExport::CommandLineUtil

    BATCH_SIZE = 100

    def initialize(portable, export_path)
      @portable = portable
      @export_path = export_path
      @lfs_json = {}
    end

    def execute
      portable.lfs_objects.find_in_batches(batch_size: BATCH_SIZE) do |batch| # rubocop: disable CodeReuse/ActiveRecord
        batch.each do |lfs_object|
          save_lfs_object(lfs_object)
        end

        append_lfs_json_for_batch(batch)
      end

      write_lfs_json
    end

    private

    attr_reader :portable, :export_path, :lfs_json

    def save_lfs_object(lfs_object)
      destination_filepath = File.join(export_path, lfs_object.oid)

      if lfs_object.local_store?
        copy_files(lfs_object.file.path, destination_filepath)
      else
        download(lfs_object.file.url, destination_filepath)
      end
    end

    # rubocop: disable CodeReuse/ActiveRecord
    def append_lfs_json_for_batch(lfs_objects_batch)
      lfs_objects_projects = LfsObjectsProject
        .select('lfs_objects.oid, array_agg(distinct lfs_objects_projects.repository_type) as repository_types')
        .joins(:lfs_object)
        .where(project: portable, lfs_object: lfs_objects_batch)
        .group('lfs_objects.oid')

      lfs_objects_projects.each do |group|
        oid = group.oid

        lfs_json[oid] ||= []
        lfs_json[oid] += group.repository_types
      end
    end
    # rubocop: enable CodeReuse/ActiveRecord

    def write_lfs_json
      filepath = File.join(export_path, "#{BulkImports::FileTransfer::ProjectConfig::LFS_OBJECTS_RELATION}.json")

      File.write(filepath, lfs_json.to_json)
    end
  end
end
