# frozen_string_literal: true

class VaccineCriteria
  def initialize(programme:, vaccine_methods:, without_gelatine:)
    @programme = programme
    @vaccine_methods = vaccine_methods
    @without_gelatine = without_gelatine
  end

  def self.from_consentable(consentable)
    new(
      programme: consentable.programme,
      vaccine_methods: consentable.vaccine_methods,
      without_gelatine: consentable.without_gelatine
    )
  end

  def self.from_param(param)
    parts = param.split("_")

    programme_type = parts.shift
    without_gelatine = parts.last(2) == WITHOUT_GELATINE_SUFFIX
    vaccine_methods = without_gelatine ? parts[0..-3] : parts

    programme = Programme.find(programme_type)
    new(programme:, vaccine_methods:, without_gelatine:)
  end

  def self.from_programme_status(programme_status)
    new(
      programme: programme_status.programme,
      vaccine_methods: programme_status.vaccine_methods,
      without_gelatine: programme_status.without_gelatine
    )
  end

  attr_reader :programme, :vaccine_methods, :without_gelatine

  # The first method is the one most likely to be used to vaccinate the
  # patient. For example, in the case of Flu, the parents will approve
  # nasal (and then optionally injection).
  def primary_method
    vaccine_methods&.first
  end

  def apply(scope)
    scope = scope.with_disease_types(programme.disease_types)

    if vaccine_methods.present?
      scope = scope.where(method: vaccine_methods).order(method_order_node)
    end

    scope = scope.where(contains_gelatine: false) if without_gelatine

    scope
  end

  def to_param
    parts = []

    parts << programme.type
    parts += vaccine_methods
    parts << WITHOUT_GELATINE_SUFFIX.join("_") if without_gelatine

    parts.join("_")
  end

  private

  WITHOUT_GELATINE_SUFFIX = %w[without gelatine].freeze

  def method_order_node
    vaccine_methods
      .each_with_index
      .reduce(
        Arel::Nodes::Case.new(Vaccine.arel_table[:method])
      ) { |node, (method, i)| node.when(Vaccine.methods.fetch(method)).then(i) }
  end
end
