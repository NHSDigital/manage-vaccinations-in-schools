# frozen_string_literal: true

class API::Testing::TeamsController < API::Testing::BaseController
  def destroy
    keep_itself = ActiveModel::Type::Boolean.new.cast(params[:keep_itself])

    team = Team.find_by!(workgroup: params[:workgroup])
    team_id = team.id

    CohortImport.where(team:).delete_all
    ImmunisationImport.where(team:).delete_all
    ClassImport.where(team:).delete_all

    Consent.where(team:).delete_all
    ArchiveReason.where(team:).delete_all
    ImportantNotice.where(team:).delete_all

    NotifyLogEntry
      .joins(:team_location)
      .where(team_location: { team_id: })
      .delete_all

    ConsentForm.for_team(team).delete_all

    ClinicNotification.where(team_id:).delete_all

    ConsentNotification
      .joins(session: :team_location)
      .where(team_location: { team_id: })
      .delete_all

    ConsentNotification
      .joins(:team_location)
      .where(team_location: { team_id: })
      .delete_all

    SessionNotification
      .joins(session: :team_location)
      .where(team_location: { team_id: })
      .delete_all

    VaccinationRecord
      .joins(session: :team_location)
      .where(team_locations: { team_id: })
      .delete_all

    # In local dev we can end up with NotifyLogEntries without a patient
    NotifyLogEntry.where(patient_id: nil).delete_all

    PatientDeleter.call(patients: team.patients)

    Batch.where(team:).delete_all

    VaccinationRecord.where(
      performed_ods_code: team.organisation.ods_code
    ).delete_all

    Triage.where(team:).delete_all

    TeamCachedCounts.new(team).reset_all!

    Session.for_team(team).delete_all

    unless keep_itself
      TeamLocation.where(team:).delete_all
      Subteam.where(team:).delete_all
      Team.where(id: team.id).delete_all
    end

    response.stream.write "Done"
  rescue StandardError => e
    response.stream.write "Error: #{e.message}\n"
  ensure
    response.stream.close
  end

  def destroy_locations
    keep_base_locations =
      ActiveModel::Type::Boolean.new.cast(params[:keep_base_locations])

    team = Team.find_by!(workgroup: params[:workgroup])

    location_ids = team.team_locations.pluck(:location_id)

    locations = Location.where(id: location_ids)
    locations = locations.where.not(site: [nil, "A"]) if keep_base_locations

    location_ids_to_delete = locations.pluck(:id)

    AttendanceRecord.where(location_id: location_ids_to_delete).delete_all
    ClassImport.where(location_id: location_ids_to_delete).delete_all
    GillickAssessment.where(location_id: location_ids_to_delete).delete_all
    PatientLocation.where(school_id: location_ids_to_delete).delete_all
    PreScreening.where(location_id: location_ids_to_delete).delete_all
    SchoolMove.where(school_id: location_ids_to_delete).delete_all

    team_location_ids =
      TeamLocation.where(location_id: location_ids_to_delete).pluck(:id)
    Session.where(team_location_id: team_location_ids).delete_all
    TeamLocation.where(location_id: location_ids_to_delete).delete_all

    VaccinationRecord.where(location_id: location_ids_to_delete).delete_all

    location_year_group_ids =
      Location::YearGroup.where(location_id: location_ids_to_delete).pluck(:id)

    Location::ProgrammeYearGroup.where(
      location_year_group_id: location_year_group_ids
    ).delete_all

    Location::YearGroup.where(location_id: location_ids_to_delete).delete_all
    locations.delete_all

    if keep_base_locations
      Location.where(id: location_ids, site: "A").update_all(site: nil)
    end
  end
end
