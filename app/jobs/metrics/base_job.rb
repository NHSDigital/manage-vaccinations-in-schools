# frozen_string_literal: true

##
# This is a base class for jobs that export metrics to AWS CloudWatch.
#
# It configures the job to run on the `metrics` queue and does not retry if it
# fails, allowing it to be scheduled regularly.
class Metrics::BaseJob < ApplicationJobSidekiq
  # We don't retry jobs that export metrics if they fail as they are often
  #  scheduled to run regularly.
  sidekiq_options queue: :metrics, retry: false

  ##
  # Returns an +Aws::CloudWatch::Client+ instance.
  def client
    @client ||= Aws::CloudWatch::Client.new(region: "eu-west-2")
  end

  ##
  # Puts metric data under the +Mavis+ namespace, adding an `AppEnvironment`
  # dimension to each metric.
  def put_metric_data(metric_data)
    transformed_metric_data =
      metric_data.map do |metric|
        metric.merge(dimensions: metric[:dimensions] + [app_environment])
      end

    client.put_metric_data(
      namespace: "Mavis",
      metric_data: transformed_metric_data
    )
  end

  private

  def app_environment
    @app_environment ||= {
      name: "AppEnvironment",
      value: HostingEnvironment.name
    }
  end
end
