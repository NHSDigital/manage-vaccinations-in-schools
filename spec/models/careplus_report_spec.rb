# frozen_string_literal: true

# == Schema Information
#
# Table name: careplus_reports
#
#  id              :bigint           not null, primary key
#  academic_year   :integer          not null
#  csv_data        :text
#  csv_filename    :text
#  csv_removed_at  :datetime
#  date_from       :date             not null
#  date_to         :date             not null
#  programme_types :enum             not null, is an Array
#  scheduled_at    :datetime         not null
#  sent_at         :datetime
#  status          :integer          default("pending"), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  team_id         :bigint           not null
#
# Indexes
#
#  index_careplus_reports_on_programme_types            (programme_types) USING gin
#  index_careplus_reports_on_status_and_scheduled_at    (status,scheduled_at)
#  index_careplus_reports_on_team_id                    (team_id)
#  index_careplus_reports_on_team_id_and_academic_year  (team_id,academic_year)
#
# Foreign Keys
#
#  fk_rails_...  (team_id => teams.id)
#
describe CareplusReport do
  subject(:careplus_report) { build(:careplus_report) }

  describe "associations" do
    it { should belong_to(:team) }

    it do
      expect(careplus_report).to have_many(
        :careplus_report_vaccination_records
      ).dependent(:destroy)
    end

    it do
      expect(careplus_report).to have_many(:vaccination_records).through(
        :careplus_report_vaccination_records
      )
    end
  end

  describe "validations" do
    it { should be_valid }
    it { should validate_presence_of(:academic_year) }
    it { should validate_presence_of(:scheduled_at) }
    it { should validate_presence_of(:date_from) }
    it { should validate_presence_of(:date_to) }
    it { should validate_presence_of(:programme_types) }

    describe "date_from_must_precede_date_to" do
      context "when date_to is before date_from" do
        subject(:careplus_report) do
          build(
            :careplus_report,
            date_from: Date.current,
            date_to: Date.current - 1.day
          )
        end

        it { should be_invalid }

        it "adds an error on date_to" do
          careplus_report.valid?
          expect(careplus_report.errors[:date_to]).to be_present
        end
      end

      context "when date_to equals date_from" do
        subject(:careplus_report) do
          build(
            :careplus_report,
            date_from: Date.current,
            date_to: Date.current
          )
        end

        it { should be_valid }
      end
    end
  end

  describe "scopes" do
    describe ".for_academic_year" do
      subject { described_class.for_academic_year(AcademicYear.current) }

      let!(:matching) do
        create(:careplus_report, academic_year: AcademicYear.current)
      end
      let!(:other) do
        create(:careplus_report, academic_year: AcademicYear.current - 1)
      end

      it { should include(matching) }
      it { should_not include(other) }
    end

    describe ".pending_send" do
      subject { described_class.pending_send }

      let!(:due) do
        create(:careplus_report, status: :pending, scheduled_at: 1.minute.ago)
      end
      let!(:future) do
        create(
          :careplus_report,
          status: :pending,
          scheduled_at: 1.hour.from_now
        )
      end
      let!(:already_sent) do
        create(:careplus_report, :sent, scheduled_at: 1.minute.ago)
      end

      it { should include(due) }
      it { should_not include(future) }
      it { should_not include(already_sent) }
    end
  end
end
