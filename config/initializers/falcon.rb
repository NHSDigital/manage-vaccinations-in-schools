# frozen_string_literal: true

if ENV["EXPORT_WEB_METRICS"] == "true"
  require "prometheus_exporter/instrumentation"
  PrometheusExporter::Instrumentation::Process.start(type: "web")
  PrometheusExporter::Instrumentation::ActiveRecord.start
end
