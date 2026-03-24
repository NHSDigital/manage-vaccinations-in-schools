# frozen_string_literal: true

module MavisCLI
  module Teams
    class AddProgramme < Dry::CLI::Command
      desc "Adds a programme to a team"

      argument :workgroup, required: true, desc: "The workgroup of the team"

      argument :type, required: true, desc: "The type of programme to add"

      def call(workgroup:, type:)
        MavisCLI.load_rails

        team = Team.find_by(workgroup:)

        if team.nil?
          warn "Could not find team."
          return
        end

        begin
          programme = Programme.find(type)
        rescue Programme::InvalidType
          warn "Could not find programme."
          return
        end

        if team.programmes.include?(programme)
          warn "Programme is already part of the team."
          return
        end

        programme_types = (team.programme_types + [type]).sort.uniq
        academic_year = AcademicYear.pending

        ActiveRecord::Base.transaction do
          team.update!(programme_types:)

          GenericLocationFactory.call(team: team.reload, academic_year:)

          team.locations.find_each do |location|
            location.import_default_programme_year_groups!(
              [programme],
              academic_year:
            )
          end
        end
      end
    end
  end

  register "teams" do |prefix|
    prefix.register "add-programme", Teams::AddProgramme
  end
end
