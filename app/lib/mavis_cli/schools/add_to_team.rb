# frozen_string_literal: true

module MavisCLI
  module Schools
    class AddToTeam < Dry::CLI::Command
      desc "Add an existing school to a team"

      argument :team_workgroup,
               required: true,
               desc: "The workgroup of the team"
      argument :subteam_name, required: true, desc: "The name of the subteam"
      argument :urns,
               type: :array,
               required: true,
               desc: "The URN of the school (including site, if applicable)"

      option :programmes,
             type: :array,
             desc: "The programmes administered at the school"

      def call(team_workgroup:, subteam_name:, urns:, programmes: [], **)
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

        programmes =
          (programmes.empty? ? team.programmes : Programme.find_all(programmes))

        academic_year = AcademicYear.pending

        locations = []
        unless urns_are_valid?(urns, team, academic_year, locations)
          warn "URN validation failed."
          return
        end

        ActiveRecord::Base.transaction do
          locations.each do |location|
            if (
                 existing_team_locations =
                   location
                     .team_locations
                     .includes(:team, :subteam)
                     .where(academic_year:)
               )
              existing_team_locations.each do |existing_team_location|
                warn "#{location.urn_and_site} previously belonged to #{existing_team_location.name}."
              end
            end

            location.attach_to_team!(team, academic_year:, subteam:)
            location.import_year_groups_from_gias!(academic_year:)
            location.import_default_programme_year_groups!(
              programmes,
              academic_year:
            )
          end

          patients_to_update =
            Patient
              .joins(:patient_locations)
              .where(patient_locations: { school: locations })
              .distinct

          PatientTeamUpdater.call(patient_scope: patients_to_update)
        end
      end

      private

      def urns_are_valid?(urns, team, academic_year, schools)
        valid = true

        urns.each do |urn|
          location = Location.gias_school.find_by_urn_and_site(urn)

          if location.nil?
            warn "Could not find school with URN #{urn}."
            valid = false
            next
          end

          schools << location

          all_site_locations = Location.gias_school.where(urn: location.urn)

          # Skip if no sites exist
          next if all_site_locations.count == 1

          # The parent location (without site) should never be added when sites exist
          if location.site.blank?
            site_urns =
              all_site_locations
                .where.not(site: nil)
                .map(&:urn_and_site)
                .join(", ")

            warn "URN #{urn} has multiple sites in the database. " \
                   "Include all sites instead: #{site_urns}."
            valid = false
            next
          end

          # Check that all other sites for this URN are included
          all_site_locations
            .where.not(site: nil)
            .find_each do |site_location|
              site_urn = site_location.urn_and_site

              next if urns.include?(site_urn)

              # Skip if already part of the team
              if site_location
                   .team_locations
                   .where(team:, academic_year:)
                   .exists?
                next
              end

              warn "Missing site #{site_urn} - all sites for URN #{site_location.urn} must be included."
              valid = false
            end
        end

        valid
      end
    end
  end

  register "schools" do |prefix|
    prefix.register "add-to-team", Schools::AddToTeam
  end
end
