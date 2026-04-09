# frozen_string_literal: true

describe GovukNotifyPersonalisation::SessionDatesPresenter do
  subject(:session_dates_presenter) { described_class.new(personalisation) }

  include_context "govuk notify personalisation context"

  context "when session is in the future" do
    around { |example| travel_to(Date.new(2025, 9, 1)) { example.run } }

    it do
      expect(session_dates_presenter).to have_attributes(
        has_multiple_dates?: false,
        next_or_today_session_date: "Thursday 1 January",
        next_or_today_session_dates: "Thursday 1 January",
        next_or_today_session_dates_or: "Thursday 1 January",
        next_session_date: "Thursday 1 January",
        next_session_dates: "Thursday 1 January",
        next_session_dates_or: "Thursday 1 January",
        subsequent_session_dates_offered_message: ""
      )
    end
  end

  context "when the session is today" do
    let(:session) do
      create(
        :session,
        location:,
        team:,
        programmes:,
        dates: [Date.current, Date.tomorrow]
      )
    end

    it "includes today in the next or today date, but not the next date" do
      expect(session_dates_presenter).to have_attributes(
        next_or_today_session_date: Date.current.to_fs(:short_day_of_week),
        next_session_date: Date.tomorrow.to_fs(:short_day_of_week)
      )
    end
  end

  context "with multiple dates" do
    let(:session) do
      create(
        :session,
        location:,
        team:,
        programmes:,
        dates: [Date.new(2026, 1, 1), Date.new(2026, 1, 2)]
      )
    end

    context "when today is before the session starts" do
      around { |example| travel_to(Date.new(2025, 9, 1)) { example.run } }

      it do
        expect(session_dates_presenter).to have_attributes(
          has_multiple_dates?: true,
          next_or_today_session_date: "Thursday 1 January",
          next_or_today_session_dates:
            "Thursday 1 January and Friday 2 January",
          next_or_today_session_dates_or:
            "Thursday 1 January or Friday 2 January",
          next_session_date: "Thursday 1 January",
          next_session_dates: "Thursday 1 January and Friday 2 January",
          next_session_dates_or: "Thursday 1 January or Friday 2 January",
          subsequent_session_dates_offered_message:
            "If they’re not seen, they’ll be offered the vaccination on Friday 2 January."
        )
      end
    end

    context "when today is the first date" do
      around { |example| travel_to(Date.new(2026, 1, 1)) { example.run } }

      it do
        expect(session_dates_presenter).to have_attributes(
          has_multiple_dates?: false,
          next_or_today_session_date: "Thursday 1 January",
          next_or_today_session_dates:
            "Thursday 1 January and Friday 2 January",
          next_or_today_session_dates_or:
            "Thursday 1 January or Friday 2 January",
          next_session_date: "Friday 2 January",
          next_session_dates: "Friday 2 January",
          next_session_dates_or: "Friday 2 January",
          subsequent_session_dates_offered_message: ""
        )
      end
    end
  end
end
