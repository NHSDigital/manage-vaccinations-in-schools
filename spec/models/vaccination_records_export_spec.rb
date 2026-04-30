# frozen_string_literal: true

# == Schema Information
#
# Table name: vaccination_records_exports
#
#  id             :bigint           not null, primary key
#  academic_year  :integer          not null
#  date_from      :date
#  date_to        :date
#  file_format    :string           not null
#  programme_type :string           not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
describe VaccinationRecordsExport do
  subject(:export) do
    create(
      :vaccination_records_export,
      programme_type: "flu",
      academic_year: 2024,
      file_format: "mavis"
    )
  end

  it { should be_valid }

  describe "#name" do
    subject(:name) { export.name }

    it { should eq("#{Programme.flu.name} vaccination records") }

    context "when date_from and date_to are set" do
      let(:export) do
        create(
          :vaccination_records_export,
          programme_type: "flu",
          academic_year: 2024,
          file_format: "mavis",
          date_from: Date.new(2024, 9, 1),
          date_to: Date.new(2025, 7, 31)
        )
      end

      it { should include("vaccination records") }
      it { should include("September 2024") }
    end
  end

  describe "#filename" do
    subject { export.filename }

    it { should include(Programme.flu.name) }
    it { should end_with(".csv") }
  end
end
