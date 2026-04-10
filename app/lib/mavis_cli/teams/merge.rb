# frozen_string_literal: true

module MavisCLI
  module Teams
    class Merge < Dry::CLI::Command
      desc "Merge two or more teams into a new team"

      argument :workgroups,
               required: true,
               type: :array,
               desc: "Workgroups of the teams to merge"

      option :name, required: true, desc: "Name for the new team"
      option :workgroup, required: true, desc: "Workgroup for the new team"
      option :email, required: false, desc: "Email for the new team"
      option :phone, required: false, desc: "Phone for the new team"
      option :phone_instructions,
             required: false,
             desc: "Phone instructions for the new team"
      option :privacy_notice_url,
             required: false,
             desc: "Privacy notice URL for the new team"
      option :privacy_policy_url,
             required: false,
             desc: "Privacy policy URL for the new team"
      option :programme_types,
             required: false,
             desc:
               "Comma-separated programme types (defaults to union of source teams)"
      option :dry_run,
             type: :boolean,
             default: false,
             desc: "Print migration plan without making changes"

      def call(workgroups:, dry_run: false, programme_types: nil, **attrs)
        MavisCLI.load_rails

        source_teams = workgroups.map { Team.find_by(workgroup: it) }

        inferred_type = source_teams.map(&:type).uniq.sole

        inferred_programme_types =
          if programme_types.present?
            programme_types.split(",").map(&:strip)
          else
            source_teams.flat_map(&:programme_types).uniq.sort
          end

        new_team_attrs =
          attrs
            .slice(
              :name,
              :workgroup,
              :email,
              :phone,
              :phone_instructions,
              :privacy_notice_url,
              :privacy_policy_url
            )
            .compact
            .merge(
              programme_types: inferred_programme_types,
              type: inferred_type,
              organisation_id: source_teams.first.organisation_id
            )

        service = TeamMerger.new(source_teams:, new_team_attrs:)

        if dry_run
          lines = service.dry_run
          lines.each { |line| puts line }
          return
        end

        merged_team = service.call!
        puts "Merged #{source_teams.map(&:workgroup).join(", ")} into team '#{merged_team.name}'."
      rescue TeamMerger::Error => e
        e.message.split("; ").each { |msg| warn msg }
      end
    end
  end

  register "teams" do |prefix|
    prefix.register "merge", Teams::Merge
  end
end
