# frozen_string_literal: true

require "prometheus_exporter/server"
require "active_support/core_ext/enumerable"

# Custom ActiveRecord type collector that sums connection pool metrics across
# all worker processes and excludes `pid` from Prometheus labels to avoid
# high-cardinality metric series.
#
# Each worker still sends `pid` for dedup (so the MetricsContainer stores one
# entry per worker). The `metrics` method then groups by hostname + pool_name,
# sums the gauge values, and emits a single metric per group.
#
# Registered via Runner's `type_collectors` option in bin/prometheus_exporter,
# which overwrites the default ActiveRecordCollector (same type: "active_record").
module PrometheusExporter
  class CustomActiveRecordCollector < PrometheusExporter::Server::TypeCollector
    MAX_METRIC_AGE = 60

    ACTIVE_RECORD_GAUGES = {
      "connections" => "Total connections in pool",
      "busy" => "Connections in use in pool",
      "dead" => "Dead connections in pool",
      "idle" => "Idle connections in pool",
      "waiting" => "Connection requests waiting",
      "size" => "Maximum allowed connection pool size"
    }.freeze

    def initialize
      super
      @active_record_metrics =
        PrometheusExporter::Server::MetricsContainer.new(ttl: MAX_METRIC_AGE)
      @active_record_metrics.filter = ->(new_metric, old_metric) do
        new_metric["pid"] == old_metric["pid"] &&
          new_metric["hostname"] == old_metric["hostname"] &&
          new_metric["metric_labels"]["pool_name"] ==
            old_metric["metric_labels"]["pool_name"]
      end
    end

    def type
      "active_record"
    end

    def metrics
      return [] if @active_record_metrics.length.zero? # rubocop:disable Style/ZeroLengthPredicate

      aggregated = {}

      @active_record_metrics.each do |metric|
        label_key = metric["metric_labels"] || {}
        label_key.merge!(metric["custom_labels"]) if metric["custom_labels"]
        group_key = label_key.to_a.sort

        if aggregated[group_key]
          ACTIVE_RECORD_GAUGES.each_key do |key|
            aggregated[group_key][:values][key] = (
              aggregated[group_key][:values][key] || 0
            ) + (metric[key] || 0)
          end
        else
          values =
            ACTIVE_RECORD_GAUGES.keys.index_with { |key| metric[key] || 0 }
          aggregated[group_key] = { labels: label_key, values: values }
        end
      end

      metrics = {}

      aggregated.each_value do |agg|
        ACTIVE_RECORD_GAUGES.each do |key, help|
          next if (v = agg[:values][key]).nil?

          gauge =
            metrics[key] ||= PrometheusExporter::Metric::Gauge.new(
              "active_record_connection_pool_#{key}",
              help
            )
          gauge.observe(v, agg[:labels])
        end
      end

      metrics.values
    end

    def collect(obj)
      @active_record_metrics << obj
    end
  end
end
