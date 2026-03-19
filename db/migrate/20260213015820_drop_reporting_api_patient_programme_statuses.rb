# frozen_string_literal: true

class DropReportingAPIPatientProgrammeStatuses < ActiveRecord::Migration[8.1]
  def up
    drop_view :reporting_api_patient_programme_statuses, materialized: true
  end

  def down
    create_view :reporting_api_patient_programme_statuses,
                version: 10,
                materialized: true

    add_index :reporting_api_patient_programme_statuses,
              :id,
              unique: true,
              name: "ix_rapi_pps_id"
    add_index :reporting_api_patient_programme_statuses,
              %i[patient_school_local_authority_code programme_type],
              name: "ix_rapi_pps_school_la_prog"
    add_index :reporting_api_patient_programme_statuses,
              %i[team_id academic_year],
              name: "ix_rapi_pps_team_year"
    add_index :reporting_api_patient_programme_statuses,
              %i[academic_year programme_type],
              name: "ix_rapi_pps_year_prog_type"
  end
end
