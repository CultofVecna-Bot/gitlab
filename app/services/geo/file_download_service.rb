module Geo
  class FileDownloadService
    attr_reader :object_type, :object_db_id

    LEASE_TIMEOUT = 8.hours.freeze

    def initialize(object_type, object_db_id)
      @object_type = object_type
      @object_db_id = object_db_id
    end

    def execute
      try_obtain_lease do |lease|
        bytes_downloaded = downloader.execute
        success = bytes_downloaded && bytes_downloaded >= 0
        update_registry(bytes_downloaded) if success
      end
    end

    private

    def downloader
      klass = "Gitlab::Geo::#{object_type.to_s.camelize}Downloader".constantize
      klass.new(object_db_id)
    rescue NameError
      Gitlab::Geo::FileDownloader.new(object_db_id)
    end

    def try_obtain_lease
      uuid = Gitlab::ExclusiveLease.new(lease_key, timeout: LEASE_TIMEOUT).try_obtain

      return unless uuid.present?

      begin
        yield
      ensure
        Gitlab::ExclusiveLease.cancel(lease_key, uuid)
      end
    end

    def update_registry(bytes_downloaded)
      transfer = Geo::FileRegistry.find_or_initialize_by(
        file_type: object_type,
        file_id: object_db_id
      )

      transfer.bytes = bytes_downloaded
      transfer.save
    end

    def lease_key
      "file_download_service:#{object_type}:#{object_db_id}"
    end
  end
end
