# frozen_string_literal: true

describe "Notify email templates: session_clinic_cancelled", type: :view do
  subject(:rendered) do
    NotifyTemplate.find(:session_clinic_cancelled, channel: :email).render(
      personalisation
    )
  end

  let(:programme) { Programme.flu }
  let(:team) { create(:team, programmes: [programme]) }
  let(:location) { create(:generic_clinic, team:, programmes: [programme]) }
  let(:session) do
    create(
      :session,
      team:,
      location:,
      programmes: [programme],
      date: Date.new(2026, 4, 24)
    )
  end
  let(:patient) do
    create(:patient, session:, given_name: "John", family_name: "Smith")
  end
  let(:personalisation) { GovukNotifyPersonalisation.new(session:, patient:) }

  it "includes cancellation information" do
    expect(rendered[:subject]).to include("John")
    expect(rendered[:body]).to include("has been cancelled")
    expect(rendered[:body]).to include("24 April 2026")
  end
end
