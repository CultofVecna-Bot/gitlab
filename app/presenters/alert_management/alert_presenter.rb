# frozen_string_literal: true

module AlertManagement
  class AlertPresenter < Gitlab::View::Presenter::Delegated
    include Gitlab::Utils::StrongMemoize
    include IncidentManagement::Settings
    include ActionView::Helpers::UrlHelper

    MARKDOWN_LINE_BREAK = "  \n"
    HORIZONTAL_LINE = "\n\n---\n\n"

    delegate :metrics_dashboard_url, :runbook, to: :parsed_payload

    def initialize(alert, _attributes = {})
      super

      @alert = alert
      @project = alert.project
    end

    def issue_description
      [
        issue_summary_markdown,
        alert_markdown,
        incident_management_setting.issue_template_content
      ].compact.join(HORIZONTAL_LINE)
    end

    def start_time
      started_at&.strftime('%d %B %Y, %-l:%M%p (%Z)')
    end

    def details_url
      details_project_alert_management_url(project, alert.iid)
    end

    def details
      Gitlab::Utils::InlineHash.merge_keys(payload)
    end

    private

    attr_reader :alert, :project
    delegate :alert_markdown, :full_query, to: :parsed_payload

    def issue_summary_markdown
      <<~MARKDOWN.chomp
        #{metadata_list}
        #{alert_details}#{metric_embed_for_alert}
      MARKDOWN
    end

    def metadata_list
      metadata = []

      metadata << list_item('Start time', start_time)
      metadata << list_item('Severity', severity)
      metadata << list_item('full_query', backtick(full_query)) if full_query
      metadata << list_item('Service', service) if service
      metadata << list_item('Monitoring tool', monitoring_tool) if monitoring_tool
      metadata << list_item('Hosts', host_links) if hosts.any?
      metadata << list_item('Description', description) if description.present?
      metadata << list_item('GitLab alert', details_url) if details_url.present?

      metadata.join(MARKDOWN_LINE_BREAK)
    end

    def alert_details
      if details.present?
        <<~MARKDOWN.chomp

          #### Alert Details

          #{details_list}
        MARKDOWN
      end
    end

    def details_list
      details
        .map { |label, value| list_item(label, value) }
        .join(MARKDOWN_LINE_BREAK)
    end

    def metric_embed_for_alert
      "\n[](#{metrics_dashboard_url})" if metrics_dashboard_url
    end

    def list_item(key, value)
      "**#{key}:** #{value}".strip
    end

    def backtick(value)
      "`#{value}`"
    end

    def host_links
      hosts.join(' ')
    end
  end
end
