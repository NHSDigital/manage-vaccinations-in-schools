# frozen_string_literal: true

class UpdateFollowUpRequestedProgrammeStatus < ActiveRecord::Migration[8.1]
  def up
    PatientStatusUpdater.call(
      patient_scope:
        Patient.has_programme_status(
          "needs_consent_follow_up_requested", 
          programme: Programme.all,
          academic_year: AcademicYear.current
        )
    )
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
