# frozen_string_literal: true

class TriageForm
  include ActiveModel::Model
  include ActiveModel::Attributes
  include ActiveRecord::AttributeAssignment

  include Notable

  attr_accessor :patient, :session, :programme, :current_user

  attribute :add_patient_specific_direction, :boolean
  attribute :consent_vaccine_methods, array: true, default: []
  attribute :consent_without_gelatine, :boolean
  attribute :notes, :string
  attribute :status_option, :string
  attribute :delay_vaccination_until, :date

  validates :add_patient_specific_direction,
            inclusion: {
              in: [true, false]
            },
            if: :requires_add_patient_specific_direction?
  validates :status_option, inclusion: { in: :status_options }

  validates :delay_vaccination_until, presence: true, if: :delay_vaccination?
  validate :validate_delay_vaccination_until_date

  def triage=(triage)
    self.status_option =
      if triage.safe_to_vaccinate?
        if consented_vaccine_methods.length > 1
          "safe_to_vaccinate_#{triage.vaccine_method}"
        else
          "safe_to_vaccinate"
        end
      else
        triage.status
      end
  end

  def notes
    if delayed_mmr_dose?
      "Next dose #{delay_vaccination_until.strftime("%d %B %Y")}"
    else
      super
    end
  end

  def save
    save! if valid?
  end

  def save!
    ActiveRecord::Base.transaction do
      handle_patient_specific_direction
      triage = Triage.create!(triage_attributes)
      associate_triage_with_vaccination_record(triage) if delayed_mmr_dose?
      triage
    end
  end

  def delayed_mmr_dose?
    programme.mmr? && delay_vaccination_until.present?
  end

  def safe_to_vaccinate_options
    if programme.has_multiple_vaccine_methods?
      consented_vaccine_methods.map { |method| "safe_to_vaccinate_#{method}" }
    elsif consented_without_gelatine
      %w[safe_to_vaccinate_without_gelatine]
    elsif programme.vaccine_may_contain_gelatine?
      %w[safe_to_vaccinate safe_to_vaccinate_without_gelatine]
    else
      %w[safe_to_vaccinate]
    end
  end

  def other_options
    %w[keep_in_triage invite_to_clinic delay_vaccination do_not_vaccinate]
  end

  def status_options
    safe_to_vaccinate_options + other_options
  end

  def consented_to_injection? = consented_vaccine_methods.include?("injection")

  def consented_to_injection_only? = consented_vaccine_methods == ["injection"]

  def show_add_patient_specific_direction?(option)
    session.psd_enabled? && option == "safe_to_vaccinate_nasal" &&
      can_create_patient_specific_directions?
  end

  def next_mmr_dose_date
    programme_status = patient.programme_status(programme, academic_year:)

    if programme_status.cannot_vaccinate_delay_vaccination?
      programme_status.date
    elsif (first_dose_date = programme_status.date)
      (first_dose_date + 28.days).to_date
    end
  end

  private

  delegate :academic_year, :team, to: :session

  def programme_type = programme.type

  def safe_to_vaccinate? = status_option.starts_with?("safe_to_vaccinate")

  def delay_vaccination? = status_option == "delay_vaccination"

  def consented_vaccine_methods
    @consented_vaccine_methods ||=
      consent_vaccine_methods.presence ||
        consent_status_generator.vaccine_methods
  end

  def consented_without_gelatine
    @consented_without_gelatine ||=
      if !consent_without_gelatine.nil?
        consent_without_gelatine
      else
        consent_status_generator.without_gelatine
      end
  end

  def consent_status_generator
    @consent_status_generator ||=
      StatusGenerator::Consent.new(
        programme_type:,
        academic_year:,
        patient:,
        consents: patient.consents,
        vaccination_records: []
      )
  end

  def triage_attributes
    {
      academic_year:,
      notes:,
      patient:,
      performed_by: current_user,
      programme:,
      status:,
      team:,
      vaccine_method: safe_to_vaccinate? ? vaccine_method : nil,
      without_gelatine: safe_to_vaccinate? ? without_gelatine : nil,
      delay_vaccination_until:
        delay_vaccination? ? delay_vaccination_until : nil
    }
  end

  def status
    case status_option
    when "safe_to_vaccinate", "safe_to_vaccinate_injection",
         "safe_to_vaccinate_nasal", "safe_to_vaccinate_without_gelatine"
      "safe_to_vaccinate"
    else
      status_option
    end
  end

  def vaccine_method
    case status_option
    when "safe_to_vaccinate", "safe_to_vaccinate_without_gelatine"
      consented_vaccine_methods.first
    when "safe_to_vaccinate_injection"
      "injection"
    when "safe_to_vaccinate_nasal"
      "nasal"
    end
  end

  def without_gelatine
    case status_option
    when "safe_to_vaccinate_injection", "safe_to_vaccinate_without_gelatine"
      true
    when "safe_to_vaccinate", "safe_to_vaccinate_nasal"
      false
    end
  end

  def requires_add_patient_specific_direction?
    show_add_patient_specific_direction?(status_option)
  end

  def can_create_patient_specific_directions?
    PatientSpecificDirectionPolicy.new(
      current_user,
      PatientSpecificDirection
    ).create?
  end

  def handle_patient_specific_direction
    if add_patient_specific_direction
      create_patient_specific_direction!
    else
      invalidate_patient_specific_directions!
    end
  end

  def create_patient_specific_direction!
    vaccine_method = "nasal"

    # TODO: Handle programmes with multiple nasal vaccines.
    vaccine = programme.vaccines.find_by(method: vaccine_method)

    attributes = {
      academic_year:,
      delivery_site: "nose",
      invalidated_at: nil,
      patient:,
      programme_type:,
      team:,
      vaccine:,
      vaccine_method:
    }

    return if patient.patient_specific_directions.exists?(attributes)

    patient.patient_specific_directions.create!(
      created_by: current_user,
      **attributes
    )
  end

  def invalidate_patient_specific_directions!
    patient
      .patient_specific_directions
      .for_programme(programme)
      .where(academic_year:, team:)
      .invalidate_all
  end

  def validate_delay_vaccination_until_date
    return if delay_vaccination_until.nil?

    if delay_vaccination_until < Date.current
      errors.add(
        :delay_vaccination_until,
        "The vaccination cannot be in the past"
      )
    end

    cutoff_date = academic_year.to_academic_year_date_range.end

    if delay_vaccination_until > cutoff_date
      errors.add(
        :delay_vaccination_until,
        "The vaccination date cannot go beyond #{cutoff_date.strftime("%d %B %Y")}"
      )
    end

    if programme.mmr? && patient_on_last_dose? &&
         delay_vaccination_until < next_mmr_dose_date
      errors.add(
        :delay_vaccination_until,
        "The vaccination cannot take place before #{next_mmr_dose_date.to_fs(:long)}"
      )
    end
  end

  def associate_triage_with_vaccination_record(next_dose_delay_triage)
    vaccination_record =
      patient
        .vaccination_records
        .for_programme(programme)
        .order_by_performed_at
        .first

    vaccination_record.presence&.update!(next_dose_delay_triage:)
  end

  def patient_on_last_dose?
    patient.programme_status(
      programme,
      academic_year: session.academic_year
    ).on_last_dose?
  end
end
