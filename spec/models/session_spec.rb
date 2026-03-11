# frozen_string_literal: true

# == Schema Information
#
# Table name: sessions
#
#  id                            :bigint           not null, primary key
#  dates                         :date             not null, is an Array
#  days_before_consent_reminders :integer
#  national_protocol_enabled     :boolean          default(FALSE), not null
#  outbreak                      :boolean          default(FALSE), not null
#  psd_enabled                   :boolean          default(FALSE), not null
#  requires_registration         :boolean          default(TRUE), not null
#  send_consent_requests_at      :date
#  slug                          :string           not null
#  created_at                    :datetime         not null
#  updated_at                    :datetime         not null
#  team_location_id              :bigint           not null
#
# Indexes
#
#  index_sessions_on_dates             (dates) USING gin
#  index_sessions_on_team_location_id  (team_location_id)
#
# Foreign Keys
#
#  fk_rails_...  (team_location_id => team_locations.id)
#

describe Session do
  describe "scopes" do
    let(:programmes) { [Programme.sample] }

    let(:closed_session) { create(:session, :closed, programmes:) }
    let(:completed_session) { create(:session, :completed, programmes:) }
    let(:scheduled_session) { create(:session, :scheduled, programmes:) }
    let(:today_session) { create(:session, :today, programmes:) }
    let(:unscheduled_session) { create(:session, :unscheduled, programmes:) }

    describe "#has_all_programmes_of" do
      subject(:scope) { described_class.has_all_programmes_of(programmes) }

      context "with a session matching the search" do
        let(:programmes) { [Programme.sample] }
        let(:session) { create(:session, programmes:) }

        it { should include(session) }
      end

      context "with a session not matching the search" do
        let(:programmes) { [Programme.hpv] }
        let(:session) { create(:session, programmes: [Programme.flu]) }

        it { should_not include(session) }
      end

      context "with a session with multiple programmes" do
        let(:programmes) { [Programme.menacwy, Programme.td_ipv] }
        let(:session) { create(:session, programmes:) }

        it { should include(session) }
      end

      context "with a session with at least all the search programmes" do
        let(:session) do
          create(
            :session,
            programmes: [Programme.hpv, Programme.menacwy, Programme.td_ipv]
          )
        end
        let(:programmes) { [session.programmes.first] }

        it { should include(session) }
      end
    end

    describe "#in_progress" do
      subject(:scope) { described_class.in_progress }

      it { should contain_exactly(today_session) }
    end

    describe "#unscheduled" do
      subject(:scope) { described_class.unscheduled }

      it { should contain_exactly(unscheduled_session) }
    end

    describe "#scheduled" do
      subject(:scope) { described_class.scheduled }

      it { should contain_exactly(today_session, scheduled_session) }
    end

    describe "#completed" do
      subject(:scope) { described_class.completed }

      it { should contain_exactly(completed_session) }
    end

    describe "#order_by_earliest_date" do
      subject(:scope) { described_class.order_by_earliest_date }

      around { |example| travel_to(today) { example.run } }

      let(:today) { Date.new(2025, 1, 1) }

      let(:programmes) { [Programme.hpv] }

      let(:first_session_before_today) do
        create(:session, date: Date.new(2024, 12, 1), programmes:)
      end
      let(:second_session_before_today) do
        create(:session, date: Date.new(2024, 12, 2), programmes:)
      end
      let(:session_today) do
        create(:session, date: Date.new(2025, 1, 1), programmes:)
      end
      let(:first_session_after_today) do
        create(:session, date: Date.new(2025, 1, 2), programmes:)
      end
      let(:second_session_after_today) do
        create(:session, date: Date.new(2025, 1, 3), programmes:)
      end
      let(:session_without_dates) { create(:session, date: nil, programmes:) }

      it do
        expect(scope).to eq(
          [
            session_today,
            first_session_after_today,
            second_session_after_today,
            first_session_before_today,
            second_session_before_today,
            session_without_dates
          ]
        )
      end
    end
  end

  describe "#today?" do
    subject(:today?) { session.today? }

    context "when the session is scheduled for today" do
      let(:session) { create(:session, :today) }

      it { should be(true) }
    end

    context "when the session is scheduled in the past" do
      let(:session) { create(:session, :completed) }

      it { should be(false) }
    end

    context "when the session is scheduled in the future" do
      let(:session) { create(:session, :scheduled) }

      it { should be(false) }
    end
  end

  describe "#unscheduled?" do
    subject { session.reload.unscheduled? }

    let(:session) { create(:session, dates: []) }

    it { should be(true) }

    context "with a date" do
      let(:session) { create(:session, dates: [Date.current]) }

      it { should be(false) }
    end
  end

  describe "#scheduled?" do
    subject { session.reload.scheduled? }

    let(:session) { create(:session, date: nil) }

    it { should be(false) }

    context "with a date" do
      let(:session) { create(:session, dates: [Date.current]) }

      it { should be(true) }
    end
  end

  describe "#started?" do
    subject(:started?) { travel_to(today) { session.reload.started? } }

    let(:today) { Date.new(2025, 1, 15) }
    let(:programmes) { [Programme.sample] }

    context "when session has no dates" do
      let(:session) { create(:session, date: nil, programmes:) }

      it { should be(false) }
    end

    context "when today is before the first session date" do
      let(:first_date) { Date.new(2025, 1, 20) }
      let(:session) { create(:session, date: first_date, programmes:) }

      it { should be(false) }
    end

    context "when today is the first session date" do
      let(:first_date) { Date.new(2025, 1, 15) }
      let(:session) { create(:session, date: first_date, programmes:) }

      it { should be(true) }
    end

    context "when today is after the first session date but before the last" do
      let(:first_date) { Date.new(2025, 1, 10) }
      let(:second_date) { Date.new(2025, 1, 20) }
      let(:session) do
        create(:session, dates: [first_date, second_date], programmes:)
      end

      it { should be(true) }
    end

    context "when today is after the last session date" do
      let(:first_date) { Date.new(2025, 1, 10) }
      let(:last_date) { Date.new(2025, 1, 12) }
      let(:session) do
        create(:session, dates: [first_date, last_date], programmes:)
      end

      it { should be(true) }
    end

    context "when session has multiple dates and today equals the first date" do
      let(:first_date) { Date.new(2025, 1, 15) }
      let(:second_date) { Date.new(2025, 1, 16) }
      let(:third_date) { Date.new(2025, 1, 17) }
      let(:session) do
        create(
          :session,
          dates: [first_date, second_date, third_date],
          programmes:
        )
      end

      it { should be(true) }
    end
  end

  describe "#supports_delegation?" do
    subject { session.supports_delegation? }

    let(:session) { create(:session, programmes:) }

    context "with only a flu programme" do
      let(:programmes) { [Programme.flu] }

      it { should be(true) }
    end

    context "with a flu and HPV programme" do
      let(:programmes) { [Programme.flu, Programme.hpv] }

      it { should be(true) }
    end

    context "with only an HPV programme" do
      let(:programmes) { [Programme.hpv] }

      it { should be(false) }
    end
  end

  describe "#pgd_supply_enabled?" do
    subject { session.pgd_supply_enabled? }

    let(:session) { create(:session, programmes:) }

    context "with only a flu programme" do
      let(:programmes) { [Programme.flu] }

      it { should be(true) }
    end

    context "with a flu and HPV programme" do
      let(:programmes) { [Programme.flu, Programme.hpv] }

      it { should be(true) }
    end

    context "with only an HPV programme" do
      let(:programmes) { [Programme.hpv] }

      it { should be(false) }
    end
  end

  describe "#patients_with_no_consent_response_count" do
    subject(:count) { session.patients_with_no_consent_response_count }

    let(:programme) { Programme.sample }
    let(:session) { create(:session, programmes: [programme]) }

    context "when there are no patients" do
      it { should eq(0) }
    end

    context "when there are patients with different consent statuses" do
      it "returns count of patients with no response consent status" do
        create(
          :patient,
          :consent_no_response,
          session:,
          programmes: [programme]
        )
        create(
          :patient,
          :consent_given_triage_not_needed,
          session:,
          programmes: [programme]
        )

        expect(count).to eq(1)
      end
    end
  end

  describe "#year_groups" do
    let(:session) do
      create(:session, programmes: [Programme.flu, Programme.hpv])
    end

    context "when not already loaded" do
      context "for all programmes" do
        subject { session.year_groups }

        it { should contain_exactly(0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11) }
      end

      context "for a specific programmes" do
        subject { session.year_groups(programme: Programme.hpv) }

        it { should contain_exactly(8, 9, 10, 11) }
      end
    end

    context "when already loaded" do
      context "for all programmes" do
        subject do
          described_class
            .includes(:session_programme_year_groups)
            .find(session.id)
            .year_groups
        end

        it { should contain_exactly(0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11) }
      end

      context "for a specific programmes" do
        subject do
          described_class
            .includes(:session_programme_year_groups)
            .find(session.id)
            .year_groups(programme: Programme.hpv)
        end

        it { should contain_exactly(8, 9, 10, 11) }
      end
    end
  end

  describe "#vaccine_methods" do
    subject { session.vaccine_methods }

    let(:flu_programme) { Programme.flu }
    let(:hpv_programme) { Programme.hpv }

    let(:session) do
      create(:session, programmes: [flu_programme, hpv_programme])
    end

    it { should contain_exactly("injection", "nasal") }
  end

  describe "#has_multiple_vaccine_methods?" do
    subject { session.has_multiple_vaccine_methods? }

    let(:session) { create(:session, programmes: [programme]) }

    context "with a flu session" do
      let(:programme) { Programme.flu }

      it { should be(true) }
    end

    context "with an HPV session" do
      let(:programme) { Programme.hpv }

      it { should be(false) }
    end
  end

  describe "#today_or_future_dates" do
    subject(:today_or_future_dates) do
      travel_to(today) { session.today_or_future_dates }
    end

    let(:dates) do
      [Date.new(2024, 1, 1), Date.new(2024, 1, 2), Date.new(2024, 1, 3)]
    end

    let(:session) { create(:session, academic_year: 2023, dates:) }

    context "on the first day" do
      let(:today) { dates.first }

      it { should match_array(dates) }
    end

    context "on the second day" do
      let(:today) { dates.second }

      it { should match_array(dates.drop(1)) }
    end

    context "on the third day" do
      let(:today) { dates.third }

      it { should match_array(dates.drop(2)) }
    end

    context "after the session" do
      let(:today) { dates.third + 1.day }

      it { should be_empty }
    end
  end

  describe "#has_been_attended?" do
    subject { session.has_been_attended?(date:) }

    let(:session) { create(:session) }
    let(:date) { session.dates.first }

    it { should be(false) }

    context "with a Gillick assessment" do
      before { create(:gillick_assessment, :competent, session:) }

      it { should be(true) }
    end

    context "with a pre-screening" do
      before { create(:pre_screening, session:) }

      it { should be(true) }
    end

    context "with a session attendance" do
      before { create(:attendance_record, :present, session:) }

      it { should be(true) }
    end
  end

  describe "#close_consent_at" do
    subject(:close_consent_at) { session.close_consent_at }

    let(:date) { nil }

    let(:session) { create(:session, date:) }

    it { should be_nil }

    context "with a date" do
      let(:date) { Date.new(2020, 1, 2) }

      it { should eq(Date.new(2020, 1, 1)) }
    end

    context "with two dates" do
      let(:date) { Date.new(2020, 1, 2) }
      let(:session) { create(:session, dates: [date, date + 1.day]) }

      it { should eq(Date.new(2020, 1, 2)) }
    end
  end

  describe "#can_receive_consent?" do
    subject { session.can_receive_consent? }

    context "without a close consent period" do
      let(:session) { create(:session, date: nil) }

      it { should be(false) }
    end

    context "when the consent period opens in the future" do
      let(:session) { create(:session, date: 3.months.from_now.to_date) }

      it { should be(true) }
    end

    context "when the consent period closes today" do
      let(:session) { create(:session, date: Date.tomorrow) }

      it { should be(true) }
    end

    context "when the consent period closes tomorrow" do
      let(:session) { create(:session, date: Date.tomorrow + 1.day) }

      it { should be(true) }
    end

    context "when the consent period closed yesterday" do
      let(:session) { create(:session, date: Date.current) }

      it { should be(false) }
    end
  end

  describe "#open_for_consent?" do
    subject { session.open_for_consent? }

    context "without a close consent period" do
      let(:session) { create(:session, date: nil) }

      it { should be(false) }
    end

    context "when the consent period opens in the future" do
      let(:session) { create(:session, date: 3.months.from_now.to_date) }

      it { should be(false) }
    end

    context "when the consent period closes today" do
      let(:session) { create(:session, date: Date.tomorrow) }

      it { should be(true) }
    end

    context "when the consent period closes tomorrow" do
      let(:session) { create(:session, date: Date.tomorrow + 1.day) }

      it { should be(true) }
    end

    context "when the consent period closed yesterday" do
      let(:session) { create(:session, date: Date.current) }

      it { should be(false) }
    end
  end

  describe "#sync_location_programme_year_groups!" do
    subject(:sync_location_programme_year_groups!) do
      session.sync_location_programme_year_groups!(
        programme_types: programmes.map(&:type)
      )
    end

    let(:location) { create(:school, programmes:) }

    context "when session has both programmes" do
      let(:session) { create(:session, location:, programmes: []) }
      let(:programmes) { [Programme.flu, Programme.hpv] }

      it "creates session programme year groups" do
        expect { sync_location_programme_year_groups! }.to change(
          Session::ProgrammeYearGroup,
          :count
        ).by(16)
      end
    end

    context "when session has only one of the programmes" do
      let(:session) { create(:session, location:, programmes: []) }
      let(:programmes) { [Programme.hpv] }

      it "creates session programme year groups" do
        expect { sync_location_programme_year_groups! }.to change(
          Session::ProgrammeYearGroup,
          :count
        ).by(4)
      end
    end
  end
end
