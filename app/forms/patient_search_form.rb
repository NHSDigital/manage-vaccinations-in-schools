# frozen_string_literal: true

class PatientSearchForm < SearchForm
  attr_writer :academic_year

  attribute :aged_out_of_programmes, :boolean
  attribute :archived, :boolean
  attribute :date_of_birth_day, :integer
  attribute :date_of_birth_month, :integer
  attribute :date_of_birth_year, :integer
  attribute :invited_to_clinic, :boolean
  attribute :missing_nhs_number, :boolean
  attribute :patient_specific_direction_status, :string
  attribute :programme_status_group, :string
  attribute :programme_statuses, array: true
  attribute :programme_types, array: true
  attribute :q, :string
  attribute :registration_status, :string
  attribute :vaccine_criteria, array: true
  attribute :year_groups, array: true

  delegate :apply, :programmes, to: :filter

  def initialize(current_team:, session: nil, **attributes)
    @current_team = current_team
    @session = session
    super(**attributes)
  end

  def programme_types=(values)
    super(values&.compact_blank || [])
  end

  def programme_statuses=(values)
    super(values&.compact_blank || [])
  end

  def vaccine_criteria=(values)
    super(values&.compact_blank || [])
  end

  def year_groups=(values)
    super(values&.compact_blank&.map(&:to_i)&.compact || [])
  end

  def any_filters_applied?
    attributes.any? { |_, v| v.present? }
  end

  private

  attr_reader :current_team, :session

  def academic_year
    session&.academic_year || @academic_year || AcademicYear.pending
  end

  def team = session&.team || current_team

  def filter
    PatientFilter.new(team:, session:, academic_year:, **attributes.symbolize_keys)
  end
end
