# frozen_string_literal: true

# Exports reporting API totals (from reporting_api_totals) to Prometheus as gauges.
# Runs only when ENV["EXPORT_REPORTING_METRICS"] == "true". Intended to run hourly
# on the ops service where the reporting API and Prometheus exporter are in use.
# Requires the Prometheus client to be configured (e.g. EXPORT_SIDEKIQ_METRICS=true).
class ReportingAPI::PrometheusMetricsJob < ApplicationJob
  METRICS = {
    mavis_reporting_cohort: "Distinct patients in cohort",
    mavis_reporting_vaccinated:
      "Patients vaccinated (or already vaccinated consent)",
    mavis_reporting_not_vaccinated: "Patients not vaccinated",
    mavis_reporting_consent_given:
      "Patients with consent given or not required",
    mavis_reporting_no_consent:
      "Patients with no consent (no response, refused, or conflicts)",
    mavis_reporting_consent_no_response: "Patients with no consent response",
    mavis_reporting_consent_refused: "Patients with consent refused",
    mavis_reporting_consent_conflicts: "Patients with consent conflicts"
  }.freeze

  def perform
    return unless ENV["EXPORT_REPORTING_METRICS"] == "true"
    return unless Flipper.enabled?(:reporting_api)

    client = PrometheusExporter::Client.default
    return if client.nil?

    ReportingAPI::Total.refresh!

    grouped_totals.each do |row|
      labels = {
        team_id: row.team_id.to_s,
        programme_type: row.programme_type.to_s
      }
      METRICS.each do |metric_name, description|
        value = row.public_send(metric_key(metric_name))
        gauge = client.register(:gauge, metric_name.to_s, description)
        gauge.observe(value.to_i, labels)
      end
    end
  end

  private

  def metric_key(metric_name)
    metric_name.to_s.delete_prefix("mavis_reporting_").to_sym
  end

  def grouped_totals
    scope = ReportingAPI::Total.not_archived
    groups = %i[team_id programme_type]
    scope.group(*groups).select(*groups).with_aggregate_metrics
  end
end
