# frozen_string_literal: true

# Internal Events Tracking Monitor
#
# This script provides real-time monitoring of Internal Events Tracking-related metrics and Snowplow events.
#
# Usage:
#   Run this script in your terminal with specific event names as command-line arguments. It will continuously
#   display relevant metrics and Snowplow events associated with the provided event names.
#
# Example:
#   To monitor events 'g_edit_by_web_ide' and 'g_edit_by_sfe', execute:
#   ```
#   bin/rails runner scripts/internal_events/monitor.rb g_edit_by_web_ide g_edit_by_sfe
#   ```
#
# Exiting:
#   - To exit the script, press Ctrl+C.
#

require 'terminal-table'
require 'net/http'

module ExtendedTimeFrame
  def weekly_time_range
    super.tap { |h| h[:end_date] = 1.week.from_now }
  end

  def monthly_time_range
    super.tap { |h| h[:end_date] = 1.week.from_now }
  end
end
Gitlab::Usage::TimeFrame.prepend(ExtendedTimeFrame)

def metric_definitions_from_args
  args = ARGV
  Gitlab::Usage::MetricDefinition.all.select do |metric|
    metric.available? && args.any? { |arg| metric.events.key?(arg) }
  end
end

def red(text)
  "\e[31m#{text}\e[0m"
end

def snowplow_data
  url = Gitlab::Tracking::Destinations::SnowplowMicro.new.uri.merge('/micro/good')
  response = Net::HTTP.get_response(url)

  return JSON.parse(response.body) if response.is_a?(Net::HTTPSuccess)

  raise "Request failed: #{response.code}"
end

def extract_standard_context(event)
  event['event']['contexts']['data'].each do |context|
    next unless context['schema'].start_with?('iglu:com.gitlab/gitlab_standard/jsonschema')

    return {
      user_id: context["data"]["user_id"],
      namespace_id: context["data"]["namespace_id"],
      project_id: context["data"]["project_id"],
      plan: context["data"]["plan"]
    }
  end
  {}
end

def generate_snowplow_table
  events = snowplow_data.select { |d| ARGV.include?(d["event"]["se_action"]) }
  @initial_max_timestamp ||= events.map { |e| e['rawEvent']['parameters']['dtm'].to_i }.max || 0

  rows = []
  rows << ['Event Name', 'Collector Timestamp', 'user_id', 'namespace_id', 'project_id', 'plan']
  rows << :separator

  events.each do |event|
    standard_context = extract_standard_context(event)

    row = [
      event['event']['se_action'],
      event['event']['collector_tstamp'],
      standard_context[:user_id],
      standard_context[:namespace_id],
      standard_context[:project_id],
      standard_context[:plan]
    ]

    row.map! { |value| red(value) } if event['rawEvent']['parameters']['dtm'].to_i > @initial_max_timestamp

    rows << row
  end

  Terminal::Table.new(
    title: 'SNOWPLOW EVENTS',
    rows: rows
  )
end

def relevant_events_from_args(metric_definition)
  metric_definition.events.keys.intersection(ARGV).sort
end

def generate_metrics_table
  metric_definitions = metric_definitions_from_args
  rows = []
  rows << ['Key Path', 'Monitored Events', 'Instrumentation Class', 'Initial Value', 'Current Value']
  rows << :separator

  @initial_values ||= {}

  metric_definitions.sort_by(&:key).each do |definition|
    metric = Gitlab::Usage::Metric.new(definition)
    value = metric.send(:instrumentation_object).value # rubocop:disable GitlabSecurity/PublicSend
    @initial_values[definition.key] ||= value

    initial_value = @initial_values[definition.key]

    value = red(value) if initial_value != value

    rows << [
      definition.key,
      relevant_events_from_args(definition).join(', '),
      definition.instrumentation_class,
      initial_value,
      value
    ]
  end

  Terminal::Table.new(
    title: 'RELEVANT METRICS',
    rows: rows
  )
end

print "\e[?1049h" # Stores the original screen buffer
print "\e[H" # Moves the cursor home
begin
  loop do
    metrics_table = generate_metrics_table
    events_table = generate_snowplow_table

    print "\e[H" # Moves the cursor home
    print "\e[2J" # Clears the screen buffer

    puts "Updated at #{Time.current}"
    puts "Monitored events: #{ARGV.join(', ')}"
    puts

    puts metrics_table

    puts events_table

    sleep 1
  end
ensure
  print "\e[?1049l" # Restores the original screen buffer
  print "\e[H" # Moves the cursor home
end
