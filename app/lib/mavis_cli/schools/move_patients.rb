# frozen_string_literal: true

module MavisCLI
  module Schools
    class MovePatients < Dry::CLI::Command
      desc "Move patients from one school to another"

      argument :source_urn, required: true, desc: "URN of the source team"
      argument :target_urn, required: true, desc: "URN of the target team"

      def call(source_urn:, target_urn:)
        MavisCLI.load_rails

        academic_year = AcademicYear.pending

        old_loc = Location.gias_school.find_by_urn_and_site(source_urn)
        new_loc = Location.gias_school.find_by_urn_and_site(target_urn)

        if old_loc.nil? || new_loc.nil?
          warn "Could not find one or both schools."
          return
        end

        team_id =
          old_loc.team_locations.ordered.where(academic_year:).sole.team_id

        old_team_location =
          old_loc
            .team_locations
            .includes(:team)
            .find_by!(academic_year:, team_id:)

        new_team_location =
          new_loc
            .team_locations
            .includes(:team)
            .find_or_initialize_by(academic_year:)

        if !new_team_location.team_id.nil? &&
             new_team_location.team_id != old_team_location.team_id
          raise "#{new_loc.urn} belongs to #{new_team_location.name}. Could not complete transfer."
        end

        new_team_location.update!(team_id:)

        new_loc.import_year_groups!(
          old_loc.year_groups,
          academic_year:,
          source: "cli"
        )

        old_loc
          .location_programme_year_groups
          .find_each do |location_programme_year_group|
          location_year_group =
            new_loc.location_year_groups.find_by!(
              academic_year:,
              value: location_programme_year_group.location_year_group.value
            )
          location_programme_year_group.update_column(
            :location_year_group_id,
            location_year_group.id
          )
        end

        Session.where(team_location_id: old_team_location.id).update_all(
          team_location_id: new_team_location.id
        )
        Patient.where(school_id: old_loc.id).update_all(school_id: new_loc.id)
        PatientLocation.where(
          academic_year:,
          location_id: old_loc.id
        ).update_all(location_id: new_loc.id)
        ConsentForm.where(team_location_id: old_team_location.id).update_all(
          team_location_id: new_team_location.id
        )
        ConsentForm.where(school_id: old_loc.id).update_all(
          school_id: new_loc.id
        )
        SchoolMove.where(school_id: old_loc.id).update_all(
          school_id: new_loc.id
        )
        Patient
          .where(school_id: new_loc.id)
          .find_each do |patient|
            SchoolMoveLogEntry.create!(patient:, school: new_loc)
          end

        old_team_location.destroy!

        patient_scope = Patient.where(school_id: new_loc.id)
        PatientTeamUpdater.call(patient_scope:)
      end
    end
  end

  register "schools" do |prefix|
    prefix.register "move-patients", Schools::MovePatients
  end
end
