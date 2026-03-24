# frozen_string_literal: true

module MavisCLI
  module Schools
    class RemoveFromTeam < Dry::CLI::Command
      desc "Remove an existing school from a team"

      argument :team_workgroup,
               required: true,
               desc: "The workgroup of the team"
      argument :subteam_name, required: true, desc: "The name of the subteam"
      argument :urns,
               type: :array,
               required: true,
               desc: "The URN of the school (including site, if applicable)"

      option :academic_year,
             type: :integer,
             desc:
               "The academic year to remove the school from (defaults to pending academic year)"

      def call(team_workgroup:, subteam_name:, urns:, academic_year: nil, **)
        MavisCLI.load_rails

        team = Team.find_by(workgroup: team_workgroup)

        if team.nil?
          warn "Could not find team with workgroup #{team_workgroup}."
          return
        end

        subteam = team.subteams.find_by(name: subteam_name)

        if subteam.nil?
          warn "Could not find subteam with name #{subteam_name}."
          return
        end

        academic_year ||= AcademicYear.pending

        locations =
          urns.filter_map do |urn|
            location = Location.gias_school.find_by_urn_and_site(urn)

            warn "Could not find school with URN #{urn}" if location.nil?
            location
          end

        ActiveRecord::Base.transaction do
          locations.each do |location|
            urn = location.urn_and_site
            team_locations =
              TeamLocation.includes(:team).where(
                team:,
                academic_year:,
                subteam:,
                location:
              )

            if team_locations.empty?
              warn "Could not find team location for URN #{urn}"
              next
            else
              team_location = team_locations.sole
            end

            unless team_location.safe_to_destroy?
              warn "Location #{location.id} (URN: #{urn}) cannot be removed as it has associated records."
              next
            end

            team_location.destroy!

            puts "Location #{location.id} (URN: #{urn}) has been removed from subteam #{subteam_name} " \
                   "for academic year #{academic_year}."
          end

          patients_to_update =
            Patient
              .joins(:patient_locations)
              .where(patient_locations: { location: locations })
              .distinct
          PatientTeamUpdater.call(patient_scope: patients_to_update)
        end
      end
    end
  end

  register "schools" do |prefix|
    prefix.register "remove-from-team", Schools::RemoveFromTeam
  end
end
