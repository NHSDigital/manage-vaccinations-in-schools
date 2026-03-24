# frozen_string_literal: true

module Reports::ExportFormatters
  extend ActiveSupport::Concern

  def school_urn(location:, patient:)
    if location&.gias_school?
      location.urn
    elsif (school = patient.school)
      school.urn
    else
      Location::URN_UNKNOWN
    end
  end

  def school_name(location:, patient:)
    location&.gias_school? ? location.name : patient.school&.name || ""
  end

  def care_setting(location:)
    if location&.gias_school?
      ImmunisationImportRow::CARE_SETTING_SCHOOL
    else
      ImmunisationImportRow::CARE_SETTING_COMMUNITY
    end
  end

  def clinic_name(location:, vaccination_record:)
    location&.gias_school? ? "" : vaccination_record.location_name
  end

  def consent_status(patient:, programme:, academic_year:)
    programme_status = patient.programme_status(programme, academic_year:)
    if programme_status.consent_given?
      if programme.has_multiple_vaccine_methods?
        vaccine_methods =
          programme_status.consent_vaccine_methods.map do |method|
            Vaccine.human_enum_name(:method, method).downcase
          end
        "Consent given for #{vaccine_methods.to_sentence}"
      else
        "Consent given"
      end
    elsif programme_status.consent_refused?
      "Consent refused"
    elsif programme_status.consent_conflicts?
      "Conflicting consent"
    else
      ""
    end
  end

  def consent_details(consents:)
    values =
      consents
        .sort_by(&:created_at)
        .reverse
        .map do |consent|
          "On #{consent.created_at.to_date} at #{consent.created_at.strftime("%H:%M")} " \
            "#{consent.response.humanize.upcase} by #{consent.name}"
        end

    values.join(", ")
  end

  def health_question_answers(consents:)
    health_answers = ConsolidatedHealthAnswers.new(consents).to_h

    values =
      health_answers.map do |question, responses|
        formatted_responses =
          responses.map do
            str = "#{_1[:answer]} from #{_1[:responder]}"
            str += " (#{_1[:notes]})" if _1[:notes].present?
            str
          end

        "#{question} #{formatted_responses.join(", ")}"
      end

    values.join("\r\n")
  end

  def gillick_status(gillick_assessment:)
    return "" if gillick_assessment.nil?

    if gillick_assessment.gillick_competent?
      "Gillick competent"
    else
      "Not Gillick competent"
    end
  end

  def psd_status(patient_specific_direction:)
    patient_specific_direction ? "PSD added" : ""
  end

  def vaccinated(vaccination_record:)
    vaccination_record.administered? ? "Y" : "N"
  end

  def anatomical_site(vaccination_record:)
    if vaccination_record.delivery_site
      ImmunisationImportRow::DELIVERY_SITES.key(
        vaccination_record.delivery_site
      )
    else
      ""
    end
  end

  def route_of_vaccination(vaccination_record:)
    vaccination_record.delivery_method || ""
  end

  def dose_sequence(vaccination_record:)
    if vaccination_record.administered?
      vaccination_record.dose_sequence || ""
    else
      ""
    end
  end

  def reason_not_vaccinated(vaccination_record:)
    if vaccination_record.administered?
      ""
    else
      ImmunisationImportRow::REASONS_NOT_ADMINISTERED.key(
        vaccination_record.outcome.to_sym
      )
    end
  end
end
