# frozen_string_literal: true

describe VaccinationRecordsHelper do
  describe "#vaccination_record_date" do
    subject { helper.vaccination_record_date(vaccination_record) }

    let(:vaccination_record) do
      build(:vaccination_record, performed_at: Time.zone.local(2024, 2, 1, 10))
    end

    it { should eq("01/02/2024") }
  end

  describe "#vaccination_record_today_or_date" do
    subject { helper.vaccination_record_today_or_date(vaccination_record) }

    context "when performed today" do
      let(:vaccination_record) do
        build(:vaccination_record, performed_at: Time.current)
      end

      it { should eq("today") }
    end

    context "when performed on another day" do
      let(:vaccination_record) do
        build(
          :vaccination_record,
          performed_at: Time.zone.local(2024, 2, 1, 10)
        )
      end

      it { should eq("on 1 February 2024") }
    end
  end

  describe "#vaccination_record_location" do
    subject { helper.vaccination_record_location(vaccination_record) }

    context "with a location_name" do
      let(:vaccination_record) do
        build(:vaccination_record, location_name: "Springfield School")
      end

      it { should eq("Springfield School") }
    end

    context "with a location association" do
      let(:location) { build(:gias_school, name: "Shelbyville School") }
      let(:vaccination_record) do
        build(:vaccination_record, location_name: nil, location:)
      end

      it { should eq("Shelbyville School") }
    end

    context "with no location" do
      let(:vaccination_record) do
        build(:vaccination_record, location_name: nil, location: nil)
      end

      it { should eq("Unknown") }
    end
  end
end
