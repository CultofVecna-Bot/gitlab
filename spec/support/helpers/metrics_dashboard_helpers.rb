# frozen_string_literal: true

module MetricsDashboardHelpers
  def project_with_dashboard(dashboard_path, dashboard_yml = nil)
    dashboard_yml ||= fixture_file('lib/gitlab/metrics/dashboard/sample_dashboard.yml')

    create(:project, :custom_repo, files: { dashboard_path => dashboard_yml })
  end

  def project_with_dashboard_namespace(dashboard_path, dashboard_yml = nil)
    dashboard_yml ||= fixture_file('lib/gitlab/metrics/dashboard/sample_dashboard.yml')

    create(:project, :custom_repo, namespace: namespace, path: 'monitor-project', files: { dashboard_path => dashboard_yml })
  end

  def delete_project_dashboard(project, user, dashboard_path)
    project.repository.delete_file(
      user,
      dashboard_path,
      branch_name: 'master',
      message: 'Delete dashboard'
    )

    project.repository.refresh_method_caches([:metrics_dashboard])
  end

  def load_sample_dashboard
    load_dashboard_yaml(fixture_file('lib/gitlab/metrics/dashboard/sample_dashboard.yml'))
  end

  def load_dashboard_yaml(data)
    ::Gitlab::Config::Loader::Yaml.new(data).load_raw!
  end

  def system_dashboard_path
    Metrics::Dashboard::SystemDashboardService::DASHBOARD_PATH
  end

  def pod_dashboard_path
    Metrics::Dashboard::PodDashboardService::DASHBOARD_PATH
  end

  def business_metric_title
    Enums::PrometheusMetric.group_details[:business][:group_title]
  end

  def self_monitoring_dashboard_path
    Metrics::Dashboard::SelfMonitoringDashboardService::DASHBOARD_PATH
  end
end
