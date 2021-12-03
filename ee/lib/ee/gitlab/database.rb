# frozen_string_literal: true

module EE
  module Gitlab
    module Database
      extend ActiveSupport::Concern

      GEO_DATABASE_NAME = 'geo'
      GEO_DATABASE_DIR  = 'ee/db/geo'
      EE_DATABASE_NAMES = [GEO_DATABASE_NAME].freeze

      class_methods do
        extend ::Gitlab::Utils::Override

        override :all_database_names
        def all_database_names
          super + EE_DATABASE_NAMES
        end

        def geo_database?(name)
          name.to_s == GEO_DATABASE_NAME
        end

        def geo_db_config_with_default_pool_size
          db_config_object = Geo::TrackingBase.connection_db_config

          config = db_config_object
            .configuration_hash
            .merge(pool: ::Gitlab::Database.default_pool_size)

          ActiveRecord::DatabaseConfigurations::HashConfig.new(
            db_config_object.env_name,
            db_config_object.name,
            config
          )
        end

        override :read_only?
        def read_only?
          ::Gitlab::Geo.secondary? || ::Gitlab.maintenance_mode?
        end
      end
    end
  end
end
