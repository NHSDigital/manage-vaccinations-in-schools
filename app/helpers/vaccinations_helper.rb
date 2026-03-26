# frozen_string_literal: true

module VaccinationsHelper
  def available_delivery_methods_for(object)
    object.available_delivery_methods.map do
      [it, VaccinationRecord.human_enum_name("delivery_methods", it)]
    end
  end

  def available_delivery_sites_for(object)
    object.available_delivery_sites.map do
      [it, VaccinationRecord.human_enum_name("delivery_sites", it)]
    end
  end

  def record_already_vaccinated_text(patient:, programme:, academic_year:)
    if programme.mmr?
      programme_status = patient.programme_status(programme, academic_year:)

      had_first_dose =
        programme_status.dose_sequence.present? &&
          programme_status.dose_sequence > 1

      if had_first_dose
        "Record 2nd dose as already given"
      else
        "Record 1st dose as already given"
      end
    else
      "Record as already vaccinated"
    end
  end
end
