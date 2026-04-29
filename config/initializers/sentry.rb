# frozen_string_literal: true

return if ENV["SENTRY_DISABLE"].present?

# Here we configure Sentry integration.
#
# We use the configured filter parameters to filter out PII and avoid it
#  reaching Sentry.
#
# We have also configured Sentry itself using advanced data scrubbing with the
#  following masking key:
#  [Mask] [^.*GET https://.*\?([^\s]*).*$] from [** || $error.value || $stacktrace]

require "active_support/parameter_filter"

Sentry.init do |config|
  config.dsn = Rails.application.credentials.sentry_dsn

  config.breadcrumbs_logger = %i[
    active_support_logger
    http_logger
    sentry_logger
  ]

  config.traces_sample_rate = 0.01

  config.before_send_transaction =
    lambda do |event, _hint|
      if event.transaction == "/up" || event.transaction.starts_with?("/health")
        nil
      else
        event
      end
    end

  rails_filter_parameters =
    Rails.application.config.filter_parameters.map(&:to_s)

  sensitive_env_vars =
    ENV.select do |key, _v|
      rails_filter_parameters.any? do |parameter|
        key.downcase.include?(parameter)
      end
    end

  sensitive_values_pattern = Regexp.union(sensitive_env_vars.values)

  sensitive_value_filter = ->(key, value) do
    key_is_relevant = %i[value title].include?(key)

    if key_is_relevant && sensitive_values_pattern.match?(value)
      value.gsub!(sensitive_values_pattern, "[FILTERED]")
    end
  end

  combined_filter =
    ActiveSupport::ParameterFilter.new(
      Rails.application.config.filter_parameters + [sensitive_value_filter]
    )

  config.before_send =
    lambda do |event, hint|
      exception = hint[:exception]

      # We don't want to send these errors to Sentry as they are too noisy. We
      # don't want to not raise them, however, since they trigger a retry with
      # Sidekiq, which we want. It can also be handy to have them in Splunk and
      # Cloudwatch to help with debugging.
      next if exception.is_a?(Faraday::TooManyRequestsError)

      if exception.is_a?(Faraday::ServerError) &&
           exception.message.include?(
             "https://api.service.nhs.uk/immunisation-fhir-api"
           ) && exception.message.include?("502")
        next
      end

      # We don't want these errors in Sentry in non-production environments as
      # they're not actionable.
      unless Rails.env.production?
        team_only_api_key_error =
          exception.is_a?(Notifications::Client::BadRequestError) &&
            exception.message.include?(
              NotifyDeliveryJob::TEAM_ONLY_API_KEY_MESSAGE
            )

        next if team_only_api_key_error

        next if exception.is_a?(Faraday::TooManyRequestsError)
      end

      event.extra = combined_filter.filter(event.extra) if event.extra
      event.user = combined_filter.filter(event.user) if event.user
      event.contexts = combined_filter.filter(event.contexts) if event.contexts

      event
    end
end
