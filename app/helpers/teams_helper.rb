# frozen_string_literal: true

module TeamsHelper
  include PhoneHelper

  def team_contact_name(session: nil, vaccination_record: nil)
    contact_entity(session:, vaccination_record:).name
  end

  def team_contact_email(session: nil, vaccination_record: nil)
    contact_entity(session:, vaccination_record:).email
  end

  def team_contact_phone(session: nil, vaccination_record: nil)
    format_phone_with_instructions(
      contact_entity(session:, vaccination_record:)
    )
  end

  private

  def contact_entity(session: nil, vaccination_record: nil)
    if session.nil? == vaccination_record.nil?
      raise ArgumentError,
            "provide either session: or vaccination_record:, not both or neither"
    end

    team_location =
      session&.team_location || vaccination_record&.session&.team_location ||
        vaccination_record
          &.patient
          &.school
          &.team_locations
          &.includes(:team, :subteam)
          &.ordered
          &.find_by(academic_year: AcademicYear.current)

    team_location&.subteam || team_location&.team
  end
end
