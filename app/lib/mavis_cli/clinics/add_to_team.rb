# frozen_string_literal: true

module MavisCLI
  module Clinics
    class AddToTeam < Dry::CLI::Command
      desc "Add an existing clinic to a team"

      argument :team_workgroup,
               required: true,
               desc: "The workgroup of the team"
      argument :subteam_name, required: true, desc: "The name of the subteam"
      argument :names,
               type: :array,
               required: true,
               desc: "The names of the clinics"

      def call(team_workgroup:, subteam_name:, names:, **)
        MavisCLI.load_rails

        team = Team.find_by(workgroup: team_workgroup)
        academic_year = AcademicYear.pending

        if team.nil?
          warn "Could not find team with workgroup #{team_workgroup}."
          return
        end

        subteam = team.subteams.find_by(name: subteam_name)

        if subteam.nil?
          warn "Could not find subteam with name #{subteam_name}."
          return
        end

        ActiveRecord::Base.transaction do
          names.each do |name|
            location = Location.clinic.find_by(name:)

            if location.nil?
              warn "Could not find clinic with name #{name}."
              next
            end

            if (
                 existing_team_locations =
                   location
                     .team_locations
                     .includes(:team, :subteam)
                     .where(academic_year:)
               )
              existing_team_locations.each do |existing_team_location|
                warn "#{name} previously belonged to #{existing_team_location.name}."
              end
            end

            location.attach_to_team!(team, academic_year:, subteam:)

            patients_to_update =
              Patient
                .joins(:patient_locations)
                .where(patient_locations: { school: location })
                .distinct

            PatientTeamUpdater.call(patient_scope: patients_to_update)
          end
        end
      end
    end
  end

  register "clinics" do |prefix|
    prefix.register "add-to-team", Clinics::AddToTeam
  end
end
