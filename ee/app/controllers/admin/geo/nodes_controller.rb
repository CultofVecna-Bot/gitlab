# frozen_string_literal: true

class Admin::Geo::NodesController < Admin::Geo::ApplicationController
  before_action :check_license!, except: :index
  before_action :load_node, only: [:edit, :update]

  # rubocop: disable CodeReuse/ActiveRecord
  def index
    @nodes = GeoNode.all.order(:id)
    @node = GeoNode.new

    unless Gitlab::Database.postgresql_minimum_supported_version?
      flash.now[:warning] = _('Please upgrade PostgreSQL to version 9.6 or greater. The status of the replication cannot be determined reliably with the current version.')
    end
  end
  # rubocop: enable CodeReuse/ActiveRecord

  def create
    @node = ::Geo::NodeCreateService.new(geo_node_params).execute

    if @node.persisted?
      flash[:toast] = _('Node was successfully created.')
      redirect_to admin_geo_nodes_path
    else
      @nodes = GeoNode.all

      render :form
    end
  end

  def new
    @form_title = _('Add New Node')
    render :form
  end

  def edit
    @form_title = _('Edit Geo Node')
    render :form
  end

  def update
    if ::Geo::NodeUpdateService.new(@node, geo_node_params).execute
      flash[:toast] = _('Node was successfully updated.')
      redirect_to admin_geo_nodes_path
    else
      render :form
    end
  end

  private

  def geo_node_params
    params.require(:geo_node).permit(
      :name,
      :url,
      :internal_url,
      :primary,
      :selective_sync_type,
      :namespace_ids,
      :repos_max_capacity,
      :files_max_capacity,
      :verification_max_capacity,
      :minimum_reverification_interval,
      :container_repositories_max_capacity,
      :sync_object_storage,
      selective_sync_shards: []
    )
  end

  def load_node
    @node = GeoNode.find(params[:id])
    @serialized_node = GeoNodeSerializer.new.represent(@node).to_json
  end
end
