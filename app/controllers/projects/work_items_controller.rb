# frozen_string_literal: true

class Projects::WorkItemsController < Projects::ApplicationController
  include WorkhorseAuthorization
  extend Gitlab::Utils::Override

  EXTENSION_ALLOWLIST = %w[csv].map(&:downcase).freeze

  before_action :authorize_import_access!, only: [:import_csv, :authorize] # rubocop:disable Rails/LexicallyScopedActionFilter
  before_action do
    push_force_frontend_feature_flag(:work_items, project&.work_items_feature_flag_enabled?)
    push_force_frontend_feature_flag(:work_items_mvc, project&.work_items_mvc_feature_flag_enabled?)
    push_force_frontend_feature_flag(:work_items_mvc_2, project&.work_items_mvc_2_feature_flag_enabled?)
    push_force_frontend_feature_flag(:linked_work_items, project&.linked_work_items_feature_flag_enabled?)
  end

  feature_category :team_planning
  urgency :high, [:authorize]
  urgency :low

  def import_csv
    file = import_params[:file]
    return render json: { errors: invalid_file_message }, status: :bad_request unless file_is_valid?(file)

    result = WorkItems::PrepareImportCsvService.new(project, current_user, file: file).execute

    if result.status == :error
      render json: { errors: result.message }, status: :bad_request
    else
      render json: { message: result.message }, status: :ok
    end
  end

  private

  def import_params
    params.permit(:file)
  end

  def authorize_import_access!
    can_import = can?(current_user, :import_work_items, project)
    import_csv_feature_available = Feature.enabled?(:import_export_work_items_csv, project)
    return if can_import && import_csv_feature_available

    if current_user || action_name == 'authorize'
      render_404
    else
      authenticate_user!
    end
  end

  def invalid_file_message
    supported_file_extensions = ".#{EXTENSION_ALLOWLIST.join(', .')}"
    format(_("The uploaded file was invalid. Supported file extensions are %{extensions}."),
      { extensions: supported_file_extensions })
  end

  def uploader_class
    FileUploader
  end

  def maximum_size
    Gitlab::CurrentSettings.max_attachment_size.megabytes
  end

  def file_extension_allowlist
    EXTENSION_ALLOWLIST
  end
end

Projects::WorkItemsController.prepend_mod
