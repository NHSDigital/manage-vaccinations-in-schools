# frozen_string_literal: true

describe SessionsHelper do
  describe "#session_consent_period" do
    subject { travel_to(today) { helper.session_consent_period(session) } }

    let(:today) { Date.new(2024, 10, 1) }

    let(:date) { nil }
    let(:session) { create(:session, academic_year: 2024, date:) }

    it { should eq("Not provided") }

    context "when in the past" do
      let(:date) { Date.new(2024, 9, 1) }

      it { should eq("Closed 31 August") }
    end

    context "when in the near future" do
      let(:date) { Date.new(2024, 10, 14) }

      it { should eq("Open from 23 September until 13 October") }
    end

    context "when the consent period closes today" do
      let(:date) { Date.new(2024, 10, 2) }

      it { should eq("Closes today at midnight") }
    end

    context "when in the far future" do
      let(:date) { Date.new(2025, 1, 1) }

      it { should eq("Opens 11 December") }
    end
  end

  describe "#session_dates" do
    subject { helper.session_dates(session) }

    context "without dates" do
      let(:session) { create(:session, dates: []) }

      it { should eq("No dates scheduled") }
    end

    context "with a single date" do
      let(:session) { create(:session, dates: [Date.new(2025, 1, 1)]) }

      it { should eq("1 January 2025") }
    end

    context "with two dates" do
      let(:session) do
        create(:session, dates: [Date.new(2025, 1, 1), Date.new(2025, 1, 2)])
      end

      it { should eq("1 to 2 January 2025") }
    end

    context "with three dates" do
      let(:session) do
        create(
          :session,
          dates: [
            Date.new(2025, 1, 1),
            Date.new(2025, 1, 2),
            Date.new(2025, 1, 3)
          ]
        )
      end

      it { should eq("1 to 3 January 2025 (3 dates)") }
    end

    context "with dates across multiple months" do
      let(:session) do
        create(:session, dates: [Date.new(2025, 1, 31), Date.new(2025, 2, 1)])
      end

      it { should eq("31 January to 1 February 2025") }
    end

    context "with dates across multiple years" do
      let(:session) do
        create(:session, dates: [Date.new(2025, 12, 31), Date.new(2026, 1, 1)])
      end

      it { should eq("31 December 2025 to 1 January 2026") }
    end
  end

  describe "#session_status" do
    subject { helper.session_status(session) }

    context "when unscheduled" do
      let(:session) { create(:session, :unscheduled) }

      it { should eq("Unscheduled") }
    end

    context "when scheduled" do
      let(:session) { create(:session, :scheduled) }

      it { should eq("Scheduled") }
    end

    context "when completed" do
      let(:session) { create(:session, :completed) }

      it { should eq("Completed") }
    end
  end

  describe "#session_future_dates" do
    subject { travel_to(today) { helper.session_future_dates(session) } }

    let(:today) { Date.new(2025, 6, 1) }

    context "with no future dates" do
      let(:session) { create(:session, dates: [Date.new(2025, 5, 30)]) }

      it { should eq("") }
    end

    context "with one future date" do
      let(:session) { create(:session, dates: [Date.new(2025, 6, 10)]) }

      it { should eq("Tuesday 10 June") }
    end

    context "with multiple future dates" do
      let(:session) do
        create(:session, dates: [Date.new(2025, 6, 10), Date.new(2025, 6, 17)])
      end

      it { should eq("Tuesday 10 June and Tuesday 17 June") }
    end
  end

  describe "#session_title" do
    subject(:session_title) { helper.session_title(session) }

    let(:programmes) { [Programme.hpv, Programme.flu] }
    let(:session) { create(:session, :unscheduled, programmes:, location:) }

    context "with a generic clinic location" do
      let(:location) { create(:generic_clinic, programmes:) }

      it { should eq("Flu and HPV community clinic") }
    end

    context "with a school location" do
      let(:location) do
        create(:gias_school, name: "Waterloo Road", programmes:)
      end

      it { should eq("Flu and HPV session at Waterloo Road") }
    end
  end

  describe "#session_caption" do
    subject(:session_caption) { helper.session_caption(session) }

    let(:programmes) { [Programme.hpv, Programme.flu] }
    let(:location) { create(:gias_school, name: "Waterloo Road", programmes:) }

    context "when unscheduled" do
      let(:session) { create(:session, :unscheduled, programmes:, location:) }

      it { should eq("Reception and years 1 to 11") }
    end

    context "when scheduled" do
      let(:session) { create(:session, :today, programmes:, location:) }

      it do
        expect(session_caption).to eq(
          "#{Date.current.to_fs(:long)} – Reception and years 1 to 11"
        )
      end
    end
  end
end
