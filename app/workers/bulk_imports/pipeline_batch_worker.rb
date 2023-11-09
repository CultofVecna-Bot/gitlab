# frozen_string_literal: true

module BulkImports
  class PipelineBatchWorker
    include ApplicationWorker
    include ExclusiveLeaseGuard

    DEFER_ON_HEALTH_DELAY = 5.minutes

    data_consistency :always # rubocop:disable SidekiqLoadBalancing/WorkerDataConsistency
    feature_category :importers
    sidekiq_options dead: false, retry: 3
    worker_has_external_dependencies!
    worker_resource_boundary :memory
    idempotent!

    sidekiq_retries_exhausted do |msg, exception|
      new.perform_failure(msg['args'].first, exception)
    end

    defer_on_database_health_signal(:gitlab_main, [], DEFER_ON_HEALTH_DELAY) do |job_args, schema, tables|
      batch = ::BulkImports::BatchTracker.find(job_args.first)
      pipeline_tracker = batch.tracker
      pipeline_schema = ::BulkImports::PipelineSchemaInfo.new(
        pipeline_tracker.pipeline_class,
        pipeline_tracker.entity.portable_class
      )

      if pipeline_schema.db_schema && pipeline_schema.db_table
        schema = pipeline_schema.db_schema
        tables = [pipeline_schema.db_table]
      end

      [schema, tables]
    end

    def self.defer_on_database_health_signal?
      Feature.enabled?(:bulk_import_deferred_workers)
    end

    def perform(batch_id)
      @batch = ::BulkImports::BatchTracker.find(batch_id)

      @tracker = @batch.tracker
      @pending_retry = false

      return unless process_batch?

      log_extra_metadata_on_done(:pipeline_class, @tracker.pipeline_name)

      try_obtain_lease { run }
    ensure
      ::BulkImports::FinishBatchedPipelineWorker.perform_async(tracker.id) unless pending_retry
    end

    def perform_failure(batch_id, exception)
      @batch = ::BulkImports::BatchTracker.find(batch_id)
      @tracker = @batch.tracker

      fail_batch(exception)
    end

    private

    attr_reader :batch, :tracker, :pending_retry

    def run
      return batch.skip! if tracker.failed? || tracker.finished?

      logger.info(log_attributes(message: 'Batch tracker started'))
      batch.start!
      tracker.pipeline_class.new(context).run
      batch.finish!
      logger.info(log_attributes(message: 'Batch tracker finished'))
    rescue BulkImports::RetryPipelineError => e
      @pending_retry = true
      retry_batch(e)
    end

    def fail_batch(exception)
      batch.fail_op!

      Gitlab::ErrorTracking.track_exception(exception, log_attributes(message: 'Batch tracker failed'))

      BulkImports::Failure.create(
        bulk_import_entity_id: batch.tracker.entity.id,
        pipeline_class: tracker.pipeline_name,
        pipeline_step: 'pipeline_batch_worker_run',
        exception_class: exception.class.to_s,
        exception_message: exception.message,
        correlation_id_value: Labkit::Correlation::CorrelationId.current_or_new_id
      )

      ::BulkImports::FinishBatchedPipelineWorker.perform_async(tracker.id)
    end

    def context
      @context ||= ::BulkImports::Pipeline::Context.new(tracker, batch_number: batch.batch_number)
    end

    def retry_batch(exception)
      batch.retry!

      re_enqueue(exception.retry_delay)
    end

    def lease_timeout
      30
    end

    def lease_key
      "gitlab:bulk_imports:pipeline_batch_worker:#{batch.id}"
    end

    def re_enqueue(delay = FILE_EXTRACTION_PIPELINE_PERFORM_DELAY)
      log_extra_metadata_on_done(:re_enqueue, true)

      self.class.perform_in(delay, batch.id)
    end

    def process_batch?
      batch.created? || batch.started?
    end

    def logger
      @logger ||= Logger.build
    end

    def log_attributes(extra = {})
      structured_payload(
        {
          batch_id: batch.id,
          batch_number: batch.batch_number,
          tracker_id: tracker.id,
          bulk_import_id: tracker.entity.bulk_import_id,
          bulk_import_entity_id: tracker.entity.id,
          pipeline_class: tracker.pipeline_name,
          pipeline_step: 'pipeline_batch_worker_run',
          importer: Logger::IMPORTER_NAME
        }.merge(extra)
      )
    end
  end
end
