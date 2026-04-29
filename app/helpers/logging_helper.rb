# frozen_string_literal: true

module LoggingHelper
  RULES = {
    id: {
      classes: [Integer, String],
      valid: ->(v) { v.is_a?(Integer) ? v.positive? : !v.empty? },
      value_error: "must be a positive Integer or non-empty String"
    },
    integer: {
      classes: [Integer],
      valid: ->(v) { !v.negative? },
      value_error: "must be a non-negative Integer"
    },
    numeric: {
      classes: [Numeric],
      valid: ->(v) { !v.negative? },
      value_error: "must be a non-negative Numeric"
    },
    application_record: {
      classes: [ApplicationRecord],
      valid: ->(v) { v.id.present? },
      value_error: "ApplicationRecord must have a present id"
    }
  }.freeze

  module_function

  def id(value)
    check_input(value, :id)
    { id: value }
  end

  def record(model)
    check_input(model, :application_record)
    { model: model.class.name, id: model.id }
  end

  def started_status
    { status: "started" }
  end

  def finished_status
    { status: "finished" }
  end

  def skipped_status
    { status: "skipped" }
  end

  def failed_status
    { status: "failed" }
  end

  def duration_ms(milliseconds)
    check_input(milliseconds, :numeric)
    { duration_ms: milliseconds }
  end

  def count(value)
    check_input(value, :integer)
    { count: value }
  end

  def check_input(value, expected_type)
    rule = RULES.fetch(expected_type)

    unless rule[:classes].any? { |klass| value.is_a?(klass) }
      raise TypeError,
            "expected #{expected_type} " \
              "(#{rule[:classes].join(" or ")}), got #{value.class}"
    end

    return if rule[:valid].call(value)

    raise ArgumentError,
          "#{expected_type} #{rule[:value_error]} (got #{value.inspect})"
  end
end

L = LoggingHelper
