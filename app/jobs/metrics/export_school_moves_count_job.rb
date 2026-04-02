# frozen_string_literal: true

class Metrics::ExportSchoolMovesCountJob < Metrics::BaseJob
  def perform
    team_workgroups = Team.order(:workgroup).pluck(:workgroup)
    counts = SchoolMove.joins_teams.group(:"teams.workgroup").count

    metric_data =
      team_workgroups.map do |team_workgroup|
        {
          metric_name: "SchoolMovesCount",
          dimensions: [{ name: "TeamWorkgroup", value: team_workgroup }],
          value: counts.fetch(team_workgroup, 0),
          unit: "Count"
        }
      end

    put_metric_data(metric_data)
  end
end
