# frozen_string_literal: true

class ReviewClassImportSchoolMoveJob < ApplicationJobActiveJob
  queue_as :imports

  def perform(import_id)
    import = ClassImport.find(import_id)

    if import.in_review? || import.low_pds_match_rate? ||
         import.in_re_review? ||
         import.changesets.any?(&:calculating_review?) ||
         import.changesets_are_invalid?
      return
    end

    patients_in_import_changesets = import.changesets.from_file.ready_for_review

    patients_in_import =
      Patient.joins(:changesets).merge(patients_in_import_changesets) +
        import.patients

    patients_in_future_review = import.changesets.needs_re_review.map(&:patient)

    unknown_patients =
      import.patients_to_create_moves_for(
        patients_in_import + patients_in_future_review
      )

    unknown_patients.map do |patient|
      PatientChangeset.create!(
        import:,
        row_number: nil,
        patient_id: patient.id,
        status: :ready_for_review,
        record_type: :not_in_file,
        data: {
          review: {
            school_move: {
              school_id: nil,
              home_educated: false
            }
          }
        }
      )
    end

    import.calculating_re_review? ? import.in_re_review! : import.in_review!
  end
end
