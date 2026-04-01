# frozen_string_literal: true

ActiveSupport::ForkTracker.after_fork { SemanticLogger.reopen }

if ENV["EXPORT_WEB_METRICS"] == "true"
  require "prometheus_exporter/instrumentation"

  ActiveSupport::ForkTracker.after_fork do
    PrometheusExporter::Instrumentation::Process.start(type: "web")
    PrometheusExporter::Instrumentation::ActiveRecord.start
  end
end
