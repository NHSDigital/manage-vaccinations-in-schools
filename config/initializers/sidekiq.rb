# frozen_string_literal: true

require "sidekiq/throttled"
require "sidekiq-unique-jobs"

redis_config = { url: ENV["SIDEKIQ_REDIS_URL"] || ENV["REDIS_URL"] }

if Rails.env.production? || Rails.env.staging?
  redis_config[:ssl_params] = { verify_mode: OpenSSL::SSL::VERIFY_NONE }
  redis_config[:timeout] = 10
end

Sidekiq.configure_server do |config|
  config.redis = redis_config

  config.client_middleware do |chain|
    chain.add SidekiqUniqueJobs::Middleware::Client
  end

  config.server_middleware do |chain|
    chain.add SidekiqUniqueJobs::Middleware::Server

    chain.add(
      Class.new do
        def call(_worker, job, _queue)
          execution_id = SecureRandom.urlsafe_base64(8)

          SemanticLogger.tagged(execution_id:) do
            Sentry.set_tags(execution_id:, jid: job["jid"])
            yield
          end
        end
      end
    )
  end

  SidekiqUniqueJobs::Server.configure(config)

  if ENV["EXPORT_SIDEKIQ_METRICS"] == "true"
    require "prometheus_exporter/instrumentation"

    config.server_middleware do |chain|
      chain.add PrometheusExporter::Instrumentation::Sidekiq
    end

    config.death_handlers << PrometheusExporter::Instrumentation::Sidekiq.death_handler

    config.on :startup do
      PrometheusExporter::Instrumentation::Process.start type: "sidekiq"
      PrometheusExporter::Instrumentation::ActiveRecord.start
      PrometheusExporter::Instrumentation::SidekiqProcess.start
      # SidekiqStats and SidekiqQueue are global Redis-backed metrics published
      # by the metrics task (bin/metrics-publisher) to avoid duplicate
      # series across Sidekiq containers.
    end

    at_exit do
      PrometheusExporter::Client.default.stop(wait_timeout_seconds: 10)
    end
  end
end

Sidekiq.configure_client do |config|
  config.redis = redis_config

  config.client_middleware do |chain|
    chain.add SidekiqUniqueJobs::Middleware::Client
  end
end

Sidekiq::Throttled.configure do |config|
  config.cooldown_period = 1.0
  config.cooldown_threshold = 1000
end

Sidekiq::Throttled::Registry.add(
  :immunisations_api,
  threshold: {
    limit: Settings.immunisations_api.rate_limit_per_second.to_i,
    period: 1.second
  }
)

# https://docs.notifications.service.gov.uk/rest-api.html#rate-limits
Sidekiq::Throttled::Registry.add(
  :govuk_notify,
  threshold: {
    limit: Settings.govuk_notify.rate_limit_per_second.to_i,
    period: 1.second
  }
)

Sidekiq::Throttled::Registry.add(
  :pds,
  threshold: {
    limit: Settings.pds.rate_limit_per_second.to_i,
    period: 1.second
  }
)
