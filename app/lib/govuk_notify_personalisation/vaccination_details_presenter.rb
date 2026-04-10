# frozen_string_literal: true

class GovukNotifyPersonalisation
  class VaccinationDetailsPresenter
    def initialize(personalisation)
      @personalisation = personalisation
    end

    attr_reader :personalisation

    delegate :academic_year,
             :mmr_second_dose_required?,
             :next_or_today_session_dates_or,
             :patient,
             :programmes,
             :programme_name_for_parents,
             :vaccination_record,
             to: :personalisation

    def is_catch_up?
      return false if patient.nil? || programmes.empty?

      @is_catch_up ||=
        programmes.any? { it.is_catch_up?(year_group: patient_year_group) }
    end

    def outcome_not_administered?
      vaccination_record.nil? || !outcome_administered?
    end

    def outcome_administered?
      vaccination_record.nil? || vaccination_record.administered?
    end

    def reason_did_not_vaccinate
      return if vaccination_record.nil? || vaccination_record.administered?

      I18n.t(
        vaccination_record.outcome,
        scope: "mailers.vaccination_mailer.reasons_did_not_vaccinate",
        short_patient_name:
      )
    end

    def show_additional_instructions? =
      vaccination_record.present? && !vaccination_record.already_had?

    def vaccination
      if vaccination_record.present?
        # We're sending communication about a specific vaccination that took place.
        "#{programme_names.to_sentence} vaccination".pluralize(
          programme_names.length
        )
      else
        # We're sending about a vaccination that will take place.
        names = programme_names

        if mmr_second_dose_required?
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

    def vaccine_is?(method)
      if vaccination_record
        vaccination_record.vaccine&.method == method
      elsif programmes.present?
        if patient
          programmes.any? do |programme|
            patient.vaccine_criteria(
              programme:,
              academic_year:
            ).primary_method == method
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
            Vaccine.for_programmes(programmes).active.flat_map(&:side_effects)
          end
        end

      return if side_effects.nil?

      descriptions =
        side_effects.map { Vaccine.human_enum_name(:side_effect, it) }.sort.uniq

      descriptions.map { "- #{it}" }.join("\n")
    end

    private

    def short_patient_name
      personalisation.short_patient_name
    end

    def patient_year_group
      @patient_year_group ||= patient.year_group(academic_year:)
    end

    def programme_names
      @programme_names ||= programmes.map { programme_name_for_parents(it) }
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
end
