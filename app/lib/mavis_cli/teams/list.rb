# frozen_string_literal: true

module MavisCLI
  module Teams
    class List < Dry::CLI::Command
      desc "List teams in Mavis"

      option :ods_code,
             desc: "The ODS code of the organisation to list teams for"

      def call(ods_code: nil)
        MavisCLI.load_rails

        teams =
          if ods_code.present?
            organisation = Organisation.find_by(ods_code:)
            if organisation.nil?
              raise ArgumentError,
                    "Could not find organisation with ODS code: #{ods_code}"
            end

            organisation.teams
          else
            Team.all
          end

        rows =
          teams.find_each.map do |team|
            team.slice(:id, :name, :workgroup, :type).merge(
              ods_code: team.organisation.ods_code,
              programmes: team.programmes.map(&:name).join(", "),
              nr_cut_off_date: team.national_reporting_cut_off_date
            )
          end

        puts TableTennis.new(
               rows,
               columns: %i[
                 id
                 name
                 type
                 ods_code
                 workgroup
                 programmes
                 nr_cut_off_date
               ],
               zebra: true
             )
      end
    end
  end

  register "teams" do |prefix|
    prefix.register "list", Teams::List
  end
end
