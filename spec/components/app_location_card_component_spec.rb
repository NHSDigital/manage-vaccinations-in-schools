# frozen_string_literal: true

describe AppLocationCardComponent do
  subject(:rendered) { travel_to(today) { render_inline(component) } }

  let(:component) do
    described_class.new(location, patient_count: 100, next_session_date: today)
  end

  let(:today) { Date.new(2025, 7, 1) }

  context "with a generic clinic" do
    let(:location) do
      create(:generic_school, :home_educated, team: create(:team))
    end

    it { should have_text("Home-educated") }
    it { should have_text("Children100 children") }
    it { should have_text("URN999999") }
    it { should have_text("PhaseOther / Unknown") }
    it { should_not have_text("Address") }
  end

  context "with a secondary school" do
    let(:location) do
      create(
        :gias_school,
        :secondary,
        urn: "123456",
        name: "Waterloo Road",
        address_line_1: "10 Waterloo Street"
      )
    end

    it { should have_text("Waterloo Road") }
    it { should have_text("Children100 children") }
    it { should have_text("URN123456") }
    it { should have_text("PhaseSecondary") }
    it { should have_text("Address10 Waterloo Street") }
    it { should have_text("Next session1 July 2025") }
  end
end
