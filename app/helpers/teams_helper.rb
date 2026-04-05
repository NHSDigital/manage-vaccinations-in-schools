# frozen_string_literal: true

module TeamsHelper
  include PhoneHelper

  def team_contact_name(session)
    (session.subteam || session.team).name
  end

  def team_contact_email(session)
    (session.subteam || session.team).email
  end

  def team_contact_phone(session)
    format_phone_with_instructions(session.subteam || session.team)
  end
end
