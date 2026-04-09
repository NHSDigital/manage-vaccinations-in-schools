# frozen_string_literal: true

shared_context "govuk notify personalisation context" do
  subject(:personalisation) do
    GovukNotifyPersonalisation.new(
      patient:,
      session:,
      consent:,
      consent_form:,
      programme_types:,
      team_location:,
      vaccination_record:
    )
  end

  let(:hpv_programme) { Programme.hpv }
  let(:flu_programme) { Programme.flu }
  let(:programmes) { [hpv_programme] }
  let(:programme_types) { programmes.map(&:type) }
  let(:ods_code) { "ABC" }
  let(:team) do
    create(
      :team,
      name: "Team",
      email: "team@example.com",
      phone: "01234 567890",
      phone_instructions: "option 1",
      programmes:,
      ods_code:
    )
  end
  let(:subteam) do
    create(
      :subteam,
      name: "Team",
      email: "team@example.com",
      phone: "01234 567890",
      phone_instructions: "option 1",
      team:
    )
  end
  let(:patient) do
    create(
      :patient,
      given_name: "John",
      family_name: "Smith",
      date_of_birth: Date.new(2013, 2, 1)
    )
  end
  let(:location) { create(:gias_school, name: "Hogwarts", subteam:) }
  let(:session) do
    create(:session, location:, team:, programmes:, date: Date.new(2026, 1, 1))
  end
  let(:team_location) { nil }
  let(:consent) { nil }
  let(:consent_form) { nil }
  let(:vaccination_record) { nil }
end
