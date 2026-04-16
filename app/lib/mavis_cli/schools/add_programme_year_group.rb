# frozen_string_literal: true

module MavisCLI
  module Schools
    class AddProgrammeYearGroup < Dry::CLI::Command
      desc "Add programme year groups to a school"

      argument :urn_or_id,
               required: true,
               desc: "School URN or ID (use --id to control)"
      argument :programme_type,
               required: true,
               desc: "The programme to add year groups to"
      argument :year_groups,
               type: :array,
               required: true,
               desc: "The year groups to add"

      option :id,
             type: :boolean,
             default: false,
             desc: "Provided school identifier is an ID"

      def call(urn_or_id:, programme_type:, year_groups:, id:, **)
        MavisCLI.load_rails

        location =
          if id
            Location.find(urn_or_id)
          else
            Location.gias_school.find_by_urn_and_site(urn_or_id)
          end

        if location.nil?
          warn "Could not find school."
          return
        end

        begin
          Programme.find(programme_type)
        rescue Programme::InvalidType
          warn "Could not find programme."
          return
        end

        academic_year = AcademicYear.pending

        ActiveRecord::Base.transaction do
          year_groups.each do |year_group|
            location_year_group =
              Location::YearGroup.create_with(source: "cli").find_or_create_by!(
                location:,
                academic_year:,
                value: year_group
              )

            Location::ProgrammeYearGroup.find_or_create_by!(
              location_year_group:,
              programme_type:
            )
          end
        end
      end
    end
  end

  register "schools" do |prefix|
    prefix.register "add-programme-year-group", Schools::AddProgrammeYearGroup
  end
end
