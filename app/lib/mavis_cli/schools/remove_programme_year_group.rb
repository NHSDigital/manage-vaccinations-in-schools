# frozen_string_literal: true

module MavisCLI
  module Schools
    class RemoveProgrammeYearGroup < Dry::CLI::Command
      desc "Remove programme year groups from a school"

      argument :urn, required: true, desc: "The URN of the school"
      argument :programme_type,
               required: true,
               desc: "The programme to remove year groups from"
      argument :year_groups,
               type: :array,
               required: true,
               desc: "The year groups to remove"

      def call(urn:, programme_type:, year_groups:, **)
        MavisCLI.load_rails

        location = Location.gias_school.find_by_urn_and_site(urn)

        if location.nil?
          warn "Could not find school."
          return
        end

        begin
          programme = Programme.find(programme_type)
        rescue Programme::InvalidType
          warn "Could not find programme."
          return
        end

        location
          .location_programme_year_groups
          .for_programme(programme)
          .where(location_year_group: { value: year_groups })
          .destroy_all
      end
    end
  end

  register "schools" do |prefix|
    prefix.register "remove-programme-year-group",
                    Schools::RemoveProgrammeYearGroup
  end
end
