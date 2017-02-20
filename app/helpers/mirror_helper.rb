module MirrorHelper
  def branch_diverged_tooltip_message
    message = "The branch could not be updated automatically because it has diverged from its upstream counterpart."
    message << "<br>To discard the local changes and overwrite the branch with the upstream version, delete it here and choose 'Update Now' above." if can?(current_user, :push_code, @project)
    message
  end

  def mirror_sync_time_options
    Gitlab::Mirror::SYNC_TIME_OPTIONS.select do |key, value|
      value >= current_application_settings.minimum_mirror_sync_time
    end
  end
end
