# frozen_string_literal: true

require_relative "../../mavis_cli"

module MavisCLI
  module Generate
    class ImmunisationImports < Dry::CLI::Command
      desc "Generate immunisation imports"

      option :team_workgroup,
             aliases: ["-w"],
             default: "A9A5A",
             desc: "Workgroup of team to generate vaccination records for"

      option :programme_types,
             aliases: ["-p"],
             default: [],
             type: :array,
             desc:
               "Programme type to generate vaccination records for (hpv, menacwy, td_ipv, etc)"

      option :count,
             aliases: ["-c"],
             type: :integer,
             required: true,
             default: 10,
             desc: "Number of vaccination records to create"

      def call(team_workgroup:, programme_types:, count:)
        MavisCLI.load_rails

        team = Team.find_by!(workgroup: team_workgroup)
        programmes = Programme.find_all(programme_types)
        count = count.to_i

        progress_bar = MavisCLI.progress_bar(count)

        puts "Generating immunisation import for team #{team_workgroup} with" \
               " #{count} patients..."

        result =
          ::Generate::ImmunisationImports.call(
            team:,
            programmes:,
            count:,
            progress_bar:
          )

        puts "\nImmunisation import CSV generated: #{result}"
      end
    end
  end

  register "generate", aliases: ["g"] do |prefix|
    prefix.register "immunisation-imports", Generate::ImmunisationImports
  end
end
