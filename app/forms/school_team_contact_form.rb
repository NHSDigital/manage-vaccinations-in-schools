# frozen_string_literal: true

class SchoolTeamContactForm
  include RequestSessionPersistable
  include WizardStepConcern

  attribute :school_id, :integer

  def initialize(request_session:, **attributes)
    super(request_session:, **attributes)
  end

  def wizard_steps
    %i[school contact_details]
  end

  on_wizard_step :school, exact: true do
    validates :school_id, presence: { message: "Select a school" }
    validate :school_must_have_team
  end

  def school
    return nil if school_id.blank?

    @school ||=
      Location
        .school
        .with_team(academic_year: AcademicYear.pending)
        .find_by(id: school_id)
  end

  def request_session_key
    "school_team_contact"
  end

  private

  def school_must_have_team
    if school_id.present? && school.nil?
      errors.add(:school_id, "Select a school")
    end
  end
end
