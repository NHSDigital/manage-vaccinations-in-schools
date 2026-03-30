# frozen_string_literal: true

class AppImportReviewSchoolMovesSummaryComponent < ViewComponent::Base
  def initialize(changesets:, pagy: nil, anchor: nil)
    @changesets =
      (
        if pagy
          changesets
        else
          changesets.sort_by { it.row_number || Float::INFINITY }
        end
      )
    @destination_schools = {}

    @pagy = pagy
    @anchor = anchor
  end

  private

  def destination_school_name(changeset)
    school = destination_school(changeset)
    home_educated = changeset.review_data.dig("school_move", "home_educated")

    if school.present?
      school.name
    elsif home_educated
      "Home educated"
    else
      "Unknown school"
    end
  end

  def destination_school(changeset)
    @destination_schools[changeset.id] ||= begin
      destination_school_id =
        changeset.review_data.dig("school_move", "school_id")
      Location.find(destination_school_id) if destination_school_id.present?
    end
  end

  def school_move_across_teams?(changeset)
    dest_school = destination_school(changeset)

    current_teams = changeset.patient.teams_via_patient_locations
    return false if current_teams.empty?

    new_teams = dest_school&.teams || [changeset.import.team]

    (new_teams & current_teams).empty?
  end

  def has_results? = @pagy&.count&.positive?
end
