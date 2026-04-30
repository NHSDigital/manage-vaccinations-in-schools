# frozen_string_literal: true

# == Schema Information
#
# Table name: patient_locations
#
#  id            :bigint           not null, primary key
#  academic_year :integer          not null
#  date_range    :daterange        default(-Infinity...Infinity), not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  patient_id    :bigint           not null
#  school_id     :bigint           not null
#
# Indexes
#
#  idx_on_patient_id_school_id_academic_year_652216fa07    (patient_id,school_id,academic_year) UNIQUE
#  idx_on_school_id_academic_year_patient_id_c647e75f26    (school_id,academic_year,patient_id) UNIQUE
#  index_patient_locations_on_school_id                    (school_id)
#  index_patient_locations_on_school_id_and_academic_year  (school_id,academic_year)
#
# Foreign Keys
#
#  fk_rails_...  (patient_id => patients.id)
#  fk_rails_...  (school_id => locations.id)
#

describe PatientLocation do
  subject(:patient_location) { create(:patient_location, session:) }

  let(:programme) { Programme.sample }
  let(:session) { create(:session, programmes: [programme]) }

  describe "associations" do
    it { should belong_to(:patient) }
    it { should belong_to(:school).class_name("Location") }
  end

  describe "scopes" do
    describe "#appear_in_programmes" do
      subject(:scope) do
        described_class
          .joins_sessions
          .joins(:patient)
          .appear_in_programmes(programmes)
      end

      let(:programmes) { [Programme.td_ipv] }
      let(:session) { create(:session, programmes:) }

      let(:patient_location) { create(:patient_location, patient:, session:) }

      it { should be_empty }

      context "in a session with the right year group" do
        let(:patient) { create(:patient, year_group: 9) }

        it { should include(patient_location) }
      end

      context "in a session but the wrong year group" do
        let(:patient) { create(:patient, year_group: 8) }

        it { should_not include(patient_location) }
      end

      context "in a session with the right year group for the programme but not the location" do
        let(:location) { create(:gias_school, :secondary) }
        let(:session) { create(:session, location:, programmes:) }
        let(:patient) { create(:patient, year_group: 9) }

        before do
          programmes.each do |programme|
            create(
              :location_programme_year_group,
              programme:,
              location:,
              year_group: 10
            )
          end
        end

        it { should_not include(patient_location) }
      end
    end

    describe "#active" do
      subject(:scope) { described_class.active }

      let!(:active_location) do
        create(
          :patient_location,
          date_range: Date.new(2020, 1, 1)...Float::INFINITY
        )
      end
      let!(:another_active_location) do
        create(
          :patient_location,
          date_range: -Float::INFINITY...Float::INFINITY
        )
      end
      let!(:inactive_location) do
        create(
          :patient_location,
          date_range: Date.new(2020, 2, 1)...Date.new(2020, 3, 1)
        )
      end

      it { should include(active_location) }
      it { should include(another_active_location) }
      it { should_not include(inactive_location) }
    end
  end

  describe "#begin_date" do
    subject { patient_location.begin_date }

    it { should be_nil }

    context "with a date range" do
      let(:patient_location) do
        create(
          :patient_location,
          date_range: Date.new(2020, 1, 1)...Date.new(2020, 2, 1)
        )
      end

      it { should eq(Date.new(2020, 1, 1)) }
    end
  end

  describe "#end_date" do
    subject { patient_location.end_date }

    it { should be_nil }

    context "with a date range" do
      let(:patient_location) do
        create(
          :patient_location,
          date_range: Date.new(2020, 1, 1)...Date.new(2020, 2, 1)
        )
      end

      it { should eq(Date.new(2020, 1, 31)) }
    end
  end

  describe "#begin_date=" do
    it "sets the beginning of the data range" do
      patient_location.begin_date = Date.new(2020, 1, 1)
      expect(patient_location.date_range).to eq(Date.new(2020, 1, 1)..)
    end
  end

  describe "#end_date=" do
    it "sets the end of the data range" do
      patient_location.end_date = Date.new(2020, 1, 31)
      expect(patient_location.date_range).to eq(..Date.new(2020, 1, 31))
    end
  end

  describe "#extend_date_range_to" do
    subject(:extend_date_range_to) do
      patient_location.extend_date_range_to(date)
    end

    let(:date) { Date.new(2020, 1, 31) }

    context "with an unlimited date range" do
      let(:patient_location) { build(:patient_location, date_range: nil...nil) }

      it "doesn't change the date range" do
        expect { extend_date_range_to }.not_to change(
          patient_location,
          :date_range
        )
      end
    end

    context "with a begin date earlier than the supplied date" do
      let(:patient_location) do
        build(:patient_location, date_range: Date.new(2020, 1, 30)..)
      end

      it "doesn't change the date range" do
        expect { extend_date_range_to }.not_to change(
          patient_location,
          :date_range
        )
      end
    end

    context "with a begin date later than the supplied date" do
      let(:patient_location) do
        build(:patient_location, date_range: Date.new(2020, 2, 1)..)
      end

      it "changes the date range" do
        expect { extend_date_range_to }.to change(
          patient_location,
          :date_range
        ).to(Date.new(2020, 1, 31)..)
      end
    end

    context "with an end date earlier than the supplied date" do
      let(:patient_location) do
        build(:patient_location, date_range: ..Date.new(2020, 1, 30))
      end

      it "changes the date range" do
        expect { extend_date_range_to }.to change(
          patient_location,
          :date_range
        ).to(..Date.new(2020, 1, 31))
      end
    end

    context "with an end date later than the supplied date" do
      let(:patient_location) do
        build(:patient_location, date_range: ..Date.new(2020, 2, 1))
      end

      it "doesn't change the date range" do
        expect { extend_date_range_to }.not_to change(
          patient_location,
          :date_range
        )
      end
    end
  end
end
