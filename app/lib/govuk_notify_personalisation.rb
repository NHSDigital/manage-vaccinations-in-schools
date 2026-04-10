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

  delegate :invitation_to_clinic_custom_mmr_message,
           :invitation_to_clinic_generic_message,
           :mmr_or_mmrv_vaccine,
           :mmr_programme,
           :mmr_second_dose_required?,
           :next_mmr_dose_date,
           :patient_on_last_dose?,
           to: :mmr_details_presenter

  delegate :delay_vaccination_review_context, to: :triage_details_presenter

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

  def mmr_details_presenter
    @mmr_details_presenter ||= MmrDetailsPresenter.new(self)
  end

  def triage_details_presenter
    @triage_details_presenter ||= TriageDetailsPresenter.new(self)
  end
end
