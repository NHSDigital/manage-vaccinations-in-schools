# frozen_string_literal: true

class API::Testing::TeamsController < API::Testing::BaseController
  include ActionController::Live

  def destroy
    response.headers["Content-Type"] = "text/event-stream"
    response.headers["Cache-Control"] = "no-cache"

    keep_itself = ActiveModel::Type::Boolean.new.cast(params[:keep_itself])

    team = Team.find_by!(workgroup: params[:workgroup])
    team_id = team.id

    @start_time = Time.zone.now

    log_destroy(CohortImport.where(team:))
    log_destroy(ImmunisationImport.where(team:))
    log_destroy(ClassImport.where(team:))

    log_destroy(Consent.where(team:))
    log_destroy(ArchiveReason.where(team:))
    log_destroy(ImportantNotice.where(team:))

    log_destroy(
      NotifyLogEntry.joins(:team_location).where(team_location: { team_id: })
    )
    log_destroy(ConsentForm.for_team(team))

    log_destroy(ClinicNotification.where(team_id:))
    log_destroy(
      ConsentNotification.joins(session: :team_location).where(
        team_location: {
          team_id:
        }
      )
    )
    log_destroy(
      ConsentNotification.joins(:team_location).where(
        team_location: {
          team_id:
        }
      )
    )
    log_destroy(
      SessionNotification.joins(session: :team_location).where(
        team_location: {
          team_id:
        }
      )
    )
    log_destroy(
      VaccinationRecord.joins(session: :team_location).where(
        team_locations: {
          team_id:
        }
      )
    )

    # In local dev we can end up with NotifyLogEntries without a patient
    log_destroy(NotifyLogEntry.where(patient_id: nil))

    log_destroy_patients(patients: team.patients)

    log_destroy(Batch.where(team:))

    log_destroy(
      VaccinationRecord.where(performed_ods_code: team.organisation.ods_code)
    )

    log_destroy(Triage.where(team:))

    TeamCachedCounts.new(team).reset_all!

    log_destroy(Session.for_team(team))

    unless keep_itself
      log_destroy(TeamLocation.where(team:))
      log_destroy(Subteam.where(team:))
      log_destroy(Team.where(id: team.id))
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

    response.headers["Content-Type"] = "text/event-stream"
    response.headers["Cache-Control"] = "no-cache"

    team = Team.find_by!(workgroup: params[:workgroup])

    location_ids = team.team_locations.pluck(:location_id)

    locations = Location.where(id: location_ids)
    locations = locations.where.not(site: [nil, "A"]) if keep_base_locations

    location_ids_to_delete = locations.pluck(:id)

    log_destroy(AttendanceRecord.where(location_id: location_ids_to_delete))
    log_destroy(ClassImport.where(location_id: location_ids_to_delete))
    log_destroy(GillickAssessment.where(location_id: location_ids_to_delete))
    log_destroy(PatientLocation.where(location_id: location_ids_to_delete))
    log_destroy(PreScreening.where(location_id: location_ids_to_delete))

    team_location_ids =
      TeamLocation.where(location_id: location_ids_to_delete).pluck(:id)
    log_destroy(Session.where(team_location_id: team_location_ids))
    log_destroy(TeamLocation.where(location_id: location_ids_to_delete))

    log_destroy(VaccinationRecord.where(location_id: location_ids_to_delete))

    location_year_group_ids =
      Location::YearGroup.where(location_id: location_ids_to_delete).pluck(:id)
    log_destroy(
      Location::ProgrammeYearGroup.where(
        location_year_group_id: location_year_group_ids
      )
    )
    log_destroy(Location::YearGroup.where(location_id: location_ids_to_delete))
    log_destroy(locations)

    if keep_base_locations
      Location.where(id: location_ids, site: "A").update_all(site: nil)
    end

    response.stream.write "Done"
  rescue StandardError => e
    response.status = :internal_server_error
    response.stream.write "Error: #{e.message}\n"
  ensure
    response.stream.close
  end

  private

  def log_destroy(query)
    where_clause = query.where_clause
    @log_time ||= Time.zone.now
    query.delete_all
    response.stream.write(
      "#{query.model.name}.where(#{where_clause.to_h}): #{Time.zone.now - @log_time}s\n"
    )
    @log_time = Time.zone.now
  end

  def log_destroy_patients(patients:)
    PatientDeleter.call(patients:)
    response.stream.write("PatientDeleter.call(patients: team.patients)")
    @log_time = Time.zone.now
  end
end
