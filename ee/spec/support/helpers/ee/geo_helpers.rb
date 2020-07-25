# frozen_string_literal: true

module EE
  module GeoHelpers
    def stub_current_geo_node(node)
      allow(::Gitlab::Geo).to receive(:current_node).and_return(node)
      allow(node).to receive(:current?).and_return(true) unless node.nil?
    end

    def stub_current_node_name(name)
      allow(GeoNode).to receive(:current_node_name).and_return(name)
    end

    def stub_primary_node
      allow(::Gitlab::Geo).to receive(:primary?).and_return(true)
      allow(::Gitlab::Geo).to receive(:secondary?).and_return(false)
    end

    def stub_secondary_node
      allow(::Gitlab::Geo).to receive(:primary?).and_return(false)
      allow(::Gitlab::Geo).to receive(:secondary?).and_return(true)
    end

    def stub_node_disabled(node)
      allow(node).to receive(:enabled?).and_return(false)
    end

    def stub_selective_sync(node, value)
      allow(node).to receive(:selective_sync?).and_return(value)
    end

    def stub_healthy_shards(shards)
      ::Gitlab::ShardHealthCache.update(Array(shards))
    end

    def create_project_on_shard(shard_name)
      project = create(:project)

      # skipping validation which requires the shard name to exist in Gitlab.config.repositories.storages.keys
      project.update_column(:repository_storage, shard_name)

      project
    end

    def registry_factory_name(registry_class)
      registry_class.underscore.tr('/', '_').to_sym
    end

    def with_no_geo_database_configured(&block)
      allow(::Gitlab::Geo).to receive(:geo_database_configured?).and_return(false)

      yield

      # We need to unstub here or the DatabaseCleaner will have issues since it
      # will appear as though the tracking DB were not available
      allow(::Gitlab::Geo).to receive(:geo_database_configured?).and_call_original
    end

    def stub_dummy_replicator_class
      stub_const('Geo::DummyReplicator', Class.new(::Gitlab::Geo::Replicator))

      Geo::DummyReplicator.class_eval do
        event :test
        event :another_test

        def self.model
          ::DummyModel
        end

        def handle_after_create_commit
          true
        end

        protected

        def consume_event_test(user:, other:)
          true
        end
      end
    end

    def stub_dummy_model_class
      stub_const('DummyModel', Class.new(ApplicationRecord))

      DummyModel.class_eval do
        include ::Gitlab::Geo::ReplicableModel

        with_replicator Geo::DummyReplicator

        def self.replicables_for_geo_node
          self.all
        end
      end

      DummyModel.reset_column_information
    end

    # Example:
    #
    # before(:all) do
    #   create_dummy_model_table
    # end
    #
    # after(:all) do
    #   drop_dummy_model_table
    # end
    def create_dummy_model_table
      ActiveRecord::Schema.define do
        create_table :dummy_models, force: true do |t|
          t.binary :verification_checksum
        end
      end
    end

    def drop_dummy_model_table
      ActiveRecord::Schema.define do
        drop_table :dummy_models, force: true
      end
    end

    def create_geo_node_to_test_replicables_for_geo_node(model, selective_sync_namespaces: nil, selective_sync_shards: nil, sync_object_storage:)
      node = build(:geo_node)

      if selective_sync_namespaces
        node.selective_sync_type = 'namespaces'
      elsif selective_sync_shards
        node.selective_sync_type = 'shards'
      end

      case selective_sync_namespaces
      when :model
        node.namespaces = [model]
      when :model_parent
        node.namespaces = [model.parent]
      when :model_parent_parent
        node.namespaces = [model.parent.parent]
      when :other
        node.namespaces = [create(:group)]
      end

      case selective_sync_shards
      when :model
        node.selective_sync_shards = [model.repository_storage]
      when :model_project
        project = create(:project, namespace: model)
        node.selective_sync_shards = [project.repository_storage]
      when :other
        node.selective_sync_shards = ['other_shard_name']
      end

      node.sync_object_storage = sync_object_storage

      node.save!
      node
    end
  end
end
