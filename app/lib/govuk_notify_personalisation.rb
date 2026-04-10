# frozen_string_literal: true

class GovukNotifyPersonalisation
  include Rails.application.routes.url_helpers

  include PatientsHelper
  include PhoneHelper
  include ProgrammesHelper
  include TeamsHelper
  include VaccinationRecordsHelper
  include VaccinesHelper

  def initialize(
    academic_year: nil,
    consent: nil,
    consent_form: nil,
    disease_types: nil,
    parent: nil,
    patient: nil,
    programme_types: nil,
    session: nil,
    team: nil,
    team_location: nil,
    vaccination_record: nil
  )
    @academic_year =
      academic_year || consent&.academic_year || consent_form&.academic_year ||
        session&.academic_year || vaccination_record&.academic_year ||
        AcademicYear.pending
    @consent = consent
    @consent_form = consent_form
    @parent = parent || consent&.parent
    @patient =
      patient || consent&.patient || vaccination_record&.patient ||
        Patient.find_by(id: consent_form&.matched_patient&.id)
    @session = session || consent_form&.session || vaccination_record&.session
    @team =
      team || session&.team || team_location&.team || consent_form&.team ||
        consent&.team || vaccination_record&.team
    @team_location =
      session&.team_location || consent_form&.team_location || team_location
    @subteam =
      session&.subteam || team_location&.subteam || consent_form&.subteam ||
        vaccination_record&.subteam
    @vaccination_record = vaccination_record

    @programmes =
      if programme_types.present?
        Programme.find_all(programme_types, disease_types:, patient: @patient)
      else
        consent_form&.programmes ||
          [consent&.programme || vaccination_record&.programme].compact
      end
  end

  attr_reader :academic_year,
              :consent,
              :consent_form,
              :parent,
              :patient,
              :programmes,
              :session,
              :subteam,
              :team,
              :team_location,
              :vaccination_record

  delegate :has_multiple_dates?,
           :next_or_today_session_date,
           :next_or_today_session_dates,
           :next_or_today_session_dates_or,
           :next_session_date,
           :next_session_dates,
           :next_session_dates_or,
           :subsequent_session_dates_offered_message,
           to: :session_dates_presenter

  delegate :consent_deadline,
           :consent_link,
           :consented_vaccine_methods_message,
           :follow_up_discussion,
           :reason_for_refusal,
           :survey_deadline_date,
           :talk_to_your_child_message,
           to: :consent_details_presenter

  delegate :is_catch_up?,
           :outcome_administered?,
           :outcome_not_administered?,
           :reason_did_not_vaccinate,
           :show_additional_instructions?,
           :vaccination,
           :vaccination_and_dates,
           :vaccination_and_dates_sms,
           :vaccination_and_method,
           :vaccine,
           :vaccine_and_dose,
           :vaccine_and_method,
           :vaccine_is?,
           :vaccine_side_effects,
           to: :vaccination_details_presenter

  delegate :privacy_notice_url, :privacy_policy_url, to: :team, prefix: true

  def full_and_preferred_patient_name
    (consent_form || patient).full_name_with_known_as(context: :parents)
  end

  def host
    if Rails.env.local?
      "http://localhost:4000"
    else
      "https://#{Settings.give_or_refuse_consent_host}"
    end
  end

  def outbreak? = session&.outbreak?

  def location_name
    if vaccination_record
      vaccination_record_location(vaccination_record)
    else
      session&.location&.name
    end
  end

  def mmr_second_dose_required?
    mmr_programme.present? && patient_on_last_dose?
  end

  def invitation_to_clinic_generic_message
    [
      (
        if mmr_second_dose_required?
          "If you would like your local GP surgery to give #{short_patient_name} " \
            "their 2nd dose, contact the surgery in the usual way."
        end
      ),
      "#{mmr_second_dose_required? ? "Alternatively, they" : "They"} can have this vaccination " \
        "at a community clinic. If you’d like to book a clinic appointment, please contact " \
        "us using the details below.",
      (mmr_second_dose_waiting_period_message if mmr_second_dose_required?)
    ].compact.join("\n\n")
  end

  def invitation_to_clinic_custom_mmr_message
    return "" unless mmr_second_dose_required?

    case team&.organisation&.ods_code
    when "RT5" # Leicestershire Partnership Trust (LPT)
      [
        mmr_second_dose_waiting_period_message,
        "It’s also possible for #{short_patient_name} to be vaccinated at your local GP surgery. " \
          "To book an appointment, contact the surgery in the usual way."
      ].join("\n\n")
    when "RYG" # Coventry & Warwickshire Partnership NHS Trust (CWPT)
      [
        mmr_second_dose_waiting_period_message,
        "## You have 2 options for booking the vaccination",
        "You can ask your local GP surgery to give #{short_patient_name} their 2nd dose. " \
          "To book an appointment, contact the surgery in the usual way."
      ].join("\n\n")
    end
  end

  def mmr_second_dose_waiting_period_message
    "It’s important to wait at least 28 days after the 1st dose of an MMR or " \
      "MMRV vaccination before getting the 2nd dose. #{short_patient_name} " \
      "should not get the 2nd dose until #{next_mmr_dose_date}. Please keep this in " \
      "mind when booking the appointment."
  end

  def next_mmr_dose_date
    return if patient.nil?
    return if mmr_programme.nil?

    patient
      .programme_status(mmr_programme, academic_year:)
      .next_dose_eligible_date
      &.to_fs(:long)
  end

  def patient_on_last_dose?
    return unless patient
    return if mmr_programme.nil?

    patient.reload.programme_status(mmr_programme, academic_year:).on_last_dose?
  end

  def mmr_or_mmrv_vaccine
    if mmr_programme.present?
      if mmr_programme.variant_type == "mmrv"
        "MMR or MMRV vaccine"
      else
        "MMR vaccine"
      end
    end
  end

  def mmr_programme
    @mmr_programme ||= programmes.find(&:mmr?)
  end

  def delay_vaccination_review_context
    return if patient.nil? || session.nil?

    latest_delayed_triage =
      patient.latest_delayed_triage(programme_types: session.programme_types)

    return if latest_delayed_triage.nil?

    session_date = session.next_date(include_today: true)
    triage_date = latest_delayed_triage.created_at.to_date

    if session_date && triage_date == session_date
      "assessed #{short_patient_name} in the vaccination session"
    else
      "reviewed the answers you gave to the health questions about #{short_patient_name}"
    end
  end

  def patient_date_of_birth
    patient&.date_of_birth&.to_fs(:long)
  end

  def short_patient_name
    (consent_form || patient)&.short_name
  end

  def short_patient_name_apos
    apos = "’"
    apos += "s" unless short_patient_name.ends_with?("s")
    short_patient_name + apos
  end

  def subteam_email = (subteam || team).email

  def subteam_name = (subteam || team).name

  def subteam_phone
    format_phone_with_instructions(subteam || team)
  end

  private

  def session_dates_are_accurate?
    consent_form ? consent_form.session_dates_are_accurate? : true
  end

  def session_dates_presenter
    @session_dates_presenter ||= SessionDatesPresenter.new(self)
  end

  def consent_details_presenter
    @consent_details_presenter ||= ConsentDetailsPresenter.new(self)
  end

  def vaccination_details_presenter
    @vaccination_details_presenter ||= VaccinationDetailsPresenter.new(self)
  end
end
