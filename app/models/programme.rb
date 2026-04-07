# frozen_string_literal: true

class Programme
  include FlipperActor
  include GelatineVaccinesConcern

  class InvalidType < StandardError
  end

  TYPES = %w[flu hpv menacwy mmr td_ipv].freeze
  MIN_MMRV_ELIGIBILITY_DATE = Date.new(2020, 1, 1).freeze

  DISEASE_TYPES = {
    "flu" => %w[influenza],
    "hpv" => %w[human_papillomavirus],
    "menacwy" => %w[meningitis_a meningitis_c meningitis_w meningitis_y],
    "mmr" => [], # This is blank because MMR has two variants with different disease types.
    "td_ipv" => %w[tetanus diphtheria polio]
  }.freeze

  DEFAULT_YEAR_GROUPS_BY_TYPE = {
    "flu" => (0..11).to_a,
    "hpv" => (8..11).to_a,
    "menacwy" => (9..11).to_a,
    "mmr" => (0..11).to_a,
    "td_ipv" => (9..11).to_a
  }.freeze

  DEFAULT_YEAR_GROUPS_WITH_OVER_16S_BY_TYPE = {
    "flu" => (0..11).to_a,
    "hpv" => (8..13).to_a,
    "menacwy" => (9..13).to_a,
    "mmr" => (0..13).to_a,
    "td_ipv" => (9..13).to_a
  }.freeze

  MAXIMUM_DOSE_SEQUENCES = {
    "flu" => 2,
    "hpv" => 3,
    "menacwy" => 3,
    "mmr" => 2,
    "td_ipv" => 6
  }.freeze

  # Minimum interval between doses. Only relevant for multi-dose
  # programmes where SAIS administers more than one dose.
  # Td/IPV intervals vary by dose number so a single value won't
  # suffice — this will need rethinking if we start scheduling
  # multiple Td/IPV doses.
  MINIMUM_DOSE_INTERVALS = {
    "flu" => nil,
    "hpv" => nil,
    "menacwy" => nil,
    "mmr" => 28.days,
    "td_ipv" => nil
  }.freeze

  IMPORT_NAMES = {
    "flu" => %w[Flu],
    "hpv" => %w[HPV],
    "menacwy" => %w[ACWYX4 MenACWY],
    "mmr" => %w[MMR MMRV],
    "td_ipv" => %w[3-in-1 Td/IPV]
  }.freeze

  SNOMED_TARGET_DISEASE_CODES = {
    "hpv" => %w[240532009].to_set,
    "flu" => %w[6142004].to_set,
    "menacwy" => %w[23511006].to_set,
    "mmr" => [], # This is blank because MMR has two variants with different disease types.
    "td_ipv" => %w[76902006 397430003 398102009].to_set
  }.freeze

  SNOMED_TARGET_DISEASE_TERMS = {
    "hpv" => ["Human papillomavirus infection"],
    "flu" => ["Influenza"],
    "menacwy" => ["Meningococcal infectious disease"],
    "mmr" => [], # This is blank because MMR has two variants with different disease types.
    "td_ipv" => [
      "Tetanus",
      "Diphtheria caused by Corynebacterium diphtheriae",
      "Acute poliomyelitis"
    ]
  }.freeze

  SNOMED_TARGET_DISEASE_NAMES = {
    "flu" => "FLU",
    "hpv" => "HPV",
    "menacwy" => "MENACWY",
    "mmr" => [], # This is blank because MMR has two variants with different disease types.
    "td_ipv" => "3IN1"
  }.freeze

  attr_reader :type

  delegate :hash, to: :type

  class << self
    def method_missing(type, *_args) = find(type.to_s)

    def respond_to_missing?(type, *_args) = exists?(type.to_s)

    def all = TYPES.map { |type| find(type) }

    def find_all(types, disease_types: nil, patient: nil)
      types.map { |type| find(type, patient:, disease_types:) }
    end

    def all_as_variants
      all.flat_map(&:variants)
    end

    def find(type, disease_types: nil, patient: nil)
      validate_type!(type)

      @programmes ||= {}
      programme = (@programmes[type] ||= new(type:))

      programme.variant_for(patient:, disease_types:)
    end

    def find_by_snomed_target_disease_codes(snomed_target_disease_codes)
      all_as_variants.find do |variant|
        variant.snomed_target_disease_codes ==
          snomed_target_disease_codes.to_set
      end
    end

    def exists?(type) = type.in?(TYPES)

    def sample = find(TYPES.sample)

    private

    def validate_type!(type)
      raise InvalidType, type unless exists?(type)
    end
  end

  def initialize(type:)
    @type = type
  end

  def to_param = type

  def id = type

  def ==(other) = type == other.type

  def eql?(other) = other.is_a?(Programme) && type.eql?(other.type)

  def <=>(other) = type <=> other.type

  def variant_type = nil

  def translation_key = mmr? ? "mmr_and_mmrv" : type

  TYPES.each do |programme_type|
    define_method("#{programme_type}?") { type == programme_type }
  end

  def name
    @name ||= I18n.t(translation_key, scope: :programme_types)
  end

  def name_in_sentence
    @name_in_sentence = flu? ? name.downcase : name
  end

  def variant_for(disease_types: nil, patient: nil)
    return self unless mmr?

    # We don't use both `patient` and `disease_types` because the patient
    #  might be eligible for a particular programme variant, but the disease
    #  types indicate a different variant was used.

    eligible_for_mmrv =
      if disease_types.present?
        disease_types.include?("varicella")
      elsif disease_types.nil? && patient
        patient.eligible_for_mmrv?
      end

    return self if eligible_for_mmrv.nil?

    variant_type = eligible_for_mmrv ? "mmrv" : "mmr"

    Programme::Variant.new(self, variant_type:)
  end

  def variants
    if mmr?
      %w[mmr mmrv].map do |variant_type|
        Programme::Variant.new(self, variant_type:)
      end
    else
      [self]
    end
  end

  def disease_types = DISEASE_TYPES.fetch(type)

  def doubles? = menacwy? || td_ipv?

  def seasonal? = flu?

  def catch_up_only? = mmr?

  def supports_delegation? = flu?

  def can_save_to_todays_batch? = !mmr?

  def triage_on_vaccination_history? = menacwy? || td_ipv?

  def default_year_groups
    if Flipper.enabled?(:vaccinating_16_plus_year_olds)
      DEFAULT_YEAR_GROUPS_WITH_OVER_16S_BY_TYPE.fetch(type)
    else
      DEFAULT_YEAR_GROUPS_BY_TYPE.fetch(type)
    end
  end

  def is_catch_up?(year_group:)
    return nil if seasonal?
    return true if catch_up_only?

    # NOTE: This logic only works if no teams administer programmes to year
    # groups earlier than the first default year group for that programme.
    # We only know of teams administering beyond the default year groups.
    default_year_groups.first != year_group
  end

  def vaccines
    @vaccines ||= Vaccine.for_programme(self)
  end

  def vaccine_methods
    @vaccine_methods ||= vaccines.map(&:method).uniq
  end

  def has_multiple_vaccine_methods? = vaccine_methods.length > 1

  def available_delivery_methods
    @available_delivery_methods ||=
      vaccines.flat_map(&:available_delivery_methods).uniq
  end

  def available_delivery_sites
    @available_delivery_sites ||=
      vaccines.flat_map(&:available_delivery_sites).uniq
  end

  def default_dose_sequence = hpv? || flu? ? 1 : nil

  def maximum_dose_sequence = MAXIMUM_DOSE_SEQUENCES.fetch(type)

  def minimum_dose_interval = MINIMUM_DOSE_INTERVALS.fetch(type)

  def import_names = IMPORT_NAMES.fetch(type)

  def snomed_target_disease_codes = SNOMED_TARGET_DISEASE_CODES.fetch(type)

  def snomed_target_disease_terms = SNOMED_TARGET_DISEASE_TERMS.fetch(type)

  def snomed_target_disease_name = SNOMED_TARGET_DISEASE_NAMES.fetch(type)

  delegate :fhir_target_disease_coding, to: :fhir_mapper

  def supports_outbreak? = mmr?

  private

  def fhir_mapper
    @fhir_mapper ||= FHIRMapper::Programme.new(self)
  end
end
