# frozen_string_literal: true

class GovukNotifyPersonalisation
  include Rails.application.routes.url_helpers

  include PhoneHelper
  include VaccinationRecordsHelper

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

  def batch_name
    vaccination_record&.batch_number
  end

  def consent_deadline
    session&.consent_deadline_date&.to_fs(:short_day_of_week)
  end

  def consent_link
    return nil if (session.nil? && team_location.nil?) || programmes.empty?

    programme_params = programmes.flat_map { it.variant_for(patient:).to_param }

    host +
      start_parent_interface_consent_forms_path(
        session || team_location,
        programme_params.join("-")
      )
  end

  def consented_vaccine_methods_message
    return if consent.nil? && consent_form.nil?

    consent_form_programmes =
      (consent ? [consent] : consent_form.consent_form_programmes)

    programmes = consent_form_programmes.map(&:programme)

    consented_vaccine_methods =
      if programmes.any?(&:has_multiple_vaccine_methods?)
        if consent_form_programmes.any?(&:vaccine_method_injection_and_nasal?)
          "nasal spray flu vaccine, or the injected flu vaccine if the nasal spray is not suitable"
        elsif consent_form_programmes.any?(&:vaccine_method_nasal?)
          "nasal spray flu vaccine"
        else
          "injected flu vaccine"
        end
      elsif programmes.any?(&:vaccine_may_contain_gelatine?)
        if consent_form_programmes.any?(&:without_gelatine)
          "vaccine without gelatine"
        end
      end

    return "" if consented_vaccine_methods.nil?

    "You’ve agreed for #{short_patient_name} to have the #{consented_vaccine_methods}."
  end

  def day_month_year_of_vaccination
    vaccination_record&.performed_at&.to_date&.to_fs(:uk_short)
  end

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

  def mmr_second_dose_message
    return unless patient
    return unless mmr_programme

    programme_status = patient.programme_status(mmr_programme, academic_year:)

    return "" if programme_status.vaccinated?

    [
      "## Your child still needs a second dose of the MMR vaccine",
      "To be fully protected against measles, mumps and rubella, your " \
        "child needs a second dose of the vaccine. Our team will be in " \
        "touch about this soon."
    ].join("\n\n")
  end

  def mmr_second_dose_required?
    mmr_programme.present? && patient_on_last_dose?
  end

  def mmr_second_dose_required
    mmr_second_dose_required?
  end

  def invitation_to_clinic_generic_message
    [
      (
        if mmr_second_dose_required
          "If you would like your local GP surgery to give #{short_patient_name} " \
            "their 2nd dose, contact the surgery in the usual way."
        end
      ),
      "#{mmr_second_dose_required ? "Alternatively, they" : "They"} can have this vaccination " \
        "at a community clinic. If you’d like to book a clinic appointment, please contact " \
        "us using the details below.",
      (mmr_second_dose_waiting_period_message if mmr_second_dose_required)
    ].compact.join("\n\n")
  end

  def invitation_to_clinic_custom_mmr_message
    return "" unless mmr_second_dose_required

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

  def next_or_today_session_date
    return "" unless session_dates_are_accurate?

    session&.next_date(include_today: true)&.to_fs(:short_day_of_week)
  end

  def next_or_today_session_dates
    return "" unless session_dates_are_accurate?

    session
      &.today_or_future_dates
      &.map { it.to_fs(:short_day_of_week) }
      &.to_sentence
  end

  def next_or_today_session_dates_or
    return "" unless session_dates_are_accurate?

    session
      &.today_or_future_dates
      &.map { it.to_fs(:short_day_of_week) }
      &.to_sentence(last_word_connector: ", or ", two_words_connector: " or ")
  end

  def next_session_date
    return "" unless session_dates_are_accurate?

    session&.next_date(include_today: false)&.to_fs(:short_day_of_week)
  end

  def next_session_dates
    return "" unless session_dates_are_accurate?

    session&.future_dates&.map { it.to_fs(:short_day_of_week) }&.to_sentence
  end

  def next_session_dates_or
    return "" unless session_dates_are_accurate?

    session
      &.future_dates
      &.map { it.to_fs(:short_day_of_week) }
      &.to_sentence(last_word_connector: ", or ", two_words_connector: " or ")
  end

  def outcome_not_administered?
    vaccination_record.nil? || !outcome_administered?
  end

  def patient_date_of_birth
    patient&.date_of_birth&.to_fs(:long)
  end

  def reason_did_not_vaccinate
    return if vaccination_record.nil? || vaccination_record.administered?

    I18n.t(
      vaccination_record.outcome,
      scope: "mailers.vaccination_mailer.reasons_did_not_vaccinate",
      short_patient_name:
    )
  end

  def reason_for_refusal
    reason = consent_form&.reason_for_refusal || consent&.reason_for_refusal
    return if reason.nil?

    I18n.t(reason, scope: "mailers.consent_form_mailer.reasons_for_refusal")
  end

  def short_patient_name
    (consent_form || patient)&.short_name
  end

  def short_patient_name_apos
    apos = "’"
    apos += "s" unless short_patient_name.ends_with?("s")
    short_patient_name + apos
  end

  def show_additional_instructions? =
    vaccination_record.present? && !vaccination_record.already_had?

  def subsequent_session_dates_offered_message
    return nil if session.nil?

    dates = session.future_dates.drop(1)
    return "" if dates.empty?

    "If they’re not seen, they’ll be offered the vaccination on #{
      dates.map { it.to_fs(:short_day_of_week) }.to_sentence
    }."
  end

  def subteam_email = (subteam || team).email

  def subteam_name = (subteam || team).name

  def subteam_phone
    format_phone_with_instructions(subteam || team)
  end

  def survey_deadline_date
    recorded_at = consent_form&.recorded_at || consent&.created_at
    return if recorded_at.nil?

    (recorded_at + 7.days).to_date.to_fs(:long)
  end

  def talk_to_your_child_message
    return nil if patient.nil?
    return "" if patient_year_group <= 6

    [
      "## Talk to your child about what they want",
      "We suggest you talk to your child about the vaccination before you respond to us. " \
        "Young people have the right to refuse vaccinations.",
      "They also have [the right to consent to their own vaccinations]" \
        "(https://www.nhs.uk/conditions/consent-to-treatment/children/) " \
        "if they show they fully understand what’s involved. Our team might give young " \
        "people this opportunity if they assess them as suitably competent."
    ].join("\n\n")
  end

  delegate :privacy_notice_url, :privacy_policy_url, to: :team, prefix: true

  def today_or_date_of_vaccination
    return if vaccination_record.nil?

    if vaccination_record.performed_at.today?
      "today"
    else
      "on #{vaccination_record.performed_at.to_date.to_fs(:long)}"
    end
  end

  def vaccination
    if vaccination_record.present?
      # We're sending communication about a specific vaccination that took place.
      "#{programme_names.to_sentence} vaccination".pluralize(
        programme_names.length
      )
    else
      # We're sending about a vaccination that will take place.
      names = programme_names

      if mmr_second_dose_required
        names = names.map { it == "MMR" ? "2nd dose of the MMR" : it }
      end

      "#{names.to_sentence} vaccination".pluralize(names.length)
    end
  end

  def vaccination_and_dates
    if next_or_today_session_dates_or.present?
      "#{vaccination} on #{next_or_today_session_dates_or}"
    else
      vaccination
    end
  end

  # TODO: Remove this method when schools start offering MMRV.
  def vaccination_and_dates_sms
    if next_or_today_session_dates_or.present?
      "#{vaccination} on #{next_or_today_session_dates_or}"
    else
      vaccination
    end
  end

  def vaccination_and_method
    "#{programme_names_and_methods.to_sentence} vaccination".pluralize(
      programme_names_and_methods.length
    )
  end

  def vaccine
    "#{programme_names.to_sentence} vaccine".pluralize(programme_names.length)
  end

  def vaccine_and_dose
    if (dose_sequence = vaccination_record&.dose_sequence)
      "#{programme_names.to_sentence} #{dose_sequence.ordinalize} dose"
    else
      programme_names.to_sentence
    end
  end

  def vaccine_and_method
    "#{programme_names_and_methods.to_sentence} vaccine".pluralize(
      programme_names_and_methods.length
    )
  end

  def vaccine_brand
    vaccination_record&.vaccine&.brand
  end

  def vaccine_is?(method)
    if vaccination_record
      vaccination_record.vaccine&.method == method
    elsif programmes.present?
      if patient
        programmes.any? do |programme|
          patient.vaccine_criteria(programme:, academic_year:).primary_method ==
            method
        end
      else
        Vaccine.for_programmes(programmes).exists?(method:)
      end
    end
  end

  def vaccine_side_effects
    side_effects =
      if vaccination_record
        vaccination_record.vaccine&.side_effects
      elsif programmes.present?
        if patient
          programmes.flat_map do |programme|
            patient.vaccine_criteria(programme:, academic_year:).side_effects
          end
        else
          Vaccine.for_programmes(programmes).flat_map(&:side_effects)
        end
      end

    return if side_effects.nil?

    descriptions =
      side_effects.map { Vaccine.human_enum_name(:side_effect, it) }.sort.uniq

    descriptions.map { "- #{it}" }.join("\n")
  end

  def is_catch_up?
    return false if patient.nil? || programmes.empty?

    @is_catch_up ||=
      programmes.any? { it.is_catch_up?(year_group: patient_year_group) }
  end

  def has_multiple_dates?
    return false if session.nil?

    session.future_dates.length > 1
  end

  def outcome_administered?
    vaccination_record.nil? || vaccination_record.administered?
  end

  private

  def session_dates_are_accurate?
    consent_form ? consent_form.session_dates_are_accurate? : true
  end

  def patient_year_group
    @patient_year_group ||= patient.year_group(academic_year:)
  end

  def programme_names
    @programme_names ||= programmes.map(&:name)
  end

  def programme_names_and_methods
    @programme_names_and_methods ||=
      programmes.map do |programme|
        if programme.has_multiple_vaccine_methods?
          vaccine_method =
            if vaccination_record
              Vaccine.delivery_method_to_vaccine_method(
                vaccination_record.delivery_method
              )
            elsif patient
              patient.vaccine_criteria(
                programme:,
                academic_year:
              ).primary_method
            end

          method_prefix =
            Vaccine.human_enum_name(:method_prefix, vaccine_method)
          "#{method_prefix} #{programme.name_in_sentence}".lstrip
        else
          programme.name_in_sentence
        end
      end
  end
end
