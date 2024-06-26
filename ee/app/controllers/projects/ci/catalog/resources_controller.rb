# frozen_string_literal: true

module Projects
  module Ci
    module Catalog
      class ResourcesController < Projects::ApplicationController
        before_action :check_catalog_access
        before_action do
          push_frontend_feature_flag(:ci_catalog_components_tab, @project)
        end
        feature_category :pipeline_composition

        def show; end

        def index
          render 'show'
        end

        private

        def check_catalog_access
          render_404 unless helpers.can_view_namespace_catalog?(@project)
        end
      end
    end
  end
end
