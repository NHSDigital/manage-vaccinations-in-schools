# frozen_string_literal: true

class GovukNotifyPersonalisation
  class MmrDetailsPresenter
    def initialize(personalisation)
      @personalisation = personalisation
    end

    attr_reader :personalisation

    delegate :academic_year,
             :patient,
             :programmes,
             :short_patient_name,
             :team,
             to: :personalisation

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

    def mmr_or_mmrv_vaccine
      return if mmr_programme.blank?

      if mmr_programme.variant_type == "mmrv"
        "MMR or MMRV vaccine"
      else
        "MMR vaccine"
      end
    end

    def mmr_programme
      @mmr_programme ||= programmes.find(&:mmr?)
    end

    def mmr_second_dose_required?
      mmr_programme.present? && patient_on_last_dose?
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

      patient
        .reload
        .programme_status(mmr_programme, academic_year:)
        .on_last_dose?
    end

    private

    def mmr_second_dose_waiting_period_message
      "It’s important to wait at least 28 days after the 1st dose of an MMR or " \
        "MMRV vaccination before getting the 2nd dose. #{short_patient_name} " \
        "should not get the 2nd dose until #{next_mmr_dose_date}. Please keep this in " \
        "mind when booking the appointment."
    end
  end
end
