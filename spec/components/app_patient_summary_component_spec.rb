# frozen_string_literal: true

describe AppPatientSummaryComponent do
  subject { render_inline(component) }

  let(:component) { described_class.new(patient) }

  let(:patient) do
    create(
      :patient,
      given_name: "Hari",
      family_name: "Seldon",
      date_of_birth: Date.new(2000, 1, 1),
      address_postcode: "SW1A 1AA"
    )
  end

  let(:href) { "/patients/#{patient.id}" }

  it { should have_content("NHS number") }

  context "when patient has an NHS number" do
    before { patient.update(nhs_number: "9993425389") }

    it { should have_content("999 342 5389") }
    it { should_not have_link("Add the child's NHS number") }
  end

  context "when patient does not have an NHS number" do
    before { patient.update(nhs_number: nil) }

    it { should have_link("Add the child's NHS number") }
  end

  it { should have_content("Date of birth") }
  it { should have_content("1 January 2000") }

  context "patient is restricted" do
    before { patient.update(restricted_at: Time.current) }

    it { should_not have_content("Address") }
    it { should_not have_content("SW1A 1AA") }
  end

  context "patient is not restricted" do
    it { should have_content("Address") }
    it { should have_content("SW1A 1AA") }
  end

  it { should have_link("View full child record", href:) }
end
