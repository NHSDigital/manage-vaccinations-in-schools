# frozen_string_literal: true

# == Schema Information
#
# Table name: vaccination_records
#
#  id                                          :bigint           not null, primary key
#  batch_expiry                                :date
#  batch_number                                :string
#  confirmation_sent_at                        :datetime
#  delivery_method                             :integer
#  delivery_site                               :integer
#  discarded_at                                :datetime
#  disease_types                               :enum             not null, is an Array
#  dose_sequence                               :integer
#  full_dose                                   :boolean
#  local_patient_id_uri                        :string
#  location_name                               :string
#  nhs_immunisations_api_etag                  :string
#  nhs_immunisations_api_identifier_system     :string
#  nhs_immunisations_api_identifier_value      :string
#  nhs_immunisations_api_primary_source        :boolean
#  nhs_immunisations_api_recorded_at           :datetime
#  nhs_immunisations_api_snomed_procedure_code :string
#  nhs_immunisations_api_snomed_procedure_term :string
#  nhs_immunisations_api_snomed_product_code   :string
#  nhs_immunisations_api_snomed_product_term   :string
#  nhs_immunisations_api_snomed_reason_code    :string
#  nhs_immunisations_api_snomed_reason_term    :string
#  nhs_immunisations_api_sync_pending_at       :datetime
#  nhs_immunisations_api_synced_at             :datetime
#  notes                                       :text
#  notify_parents                              :boolean
#  outcome                                     :integer          not null
#  pending_changes                             :jsonb            not null
#  performed_at_date                           :date             not null
#  performed_at_time                           :time
#  performed_by_family_name                    :string
#  performed_by_given_name                     :string
#  performed_ods_code                          :string
#  programme_type                              :enum             not null
#  protocol                                    :integer
#  source                                      :integer          not null
#  uuid                                        :uuid             not null
#  created_at                                  :datetime         not null
#  updated_at                                  :datetime         not null
#  duplicate_of_vaccination_record_id          :bigint
#  local_patient_id                            :string
#  location_id                                 :bigint
#  next_dose_delay_triage_id                   :bigint
#  nhs_immunisations_api_id                    :string
#  patient_id                                  :bigint           not null
#  performed_by_user_id                        :bigint
#  reported_by_id                              :bigint
#  session_id                                  :bigint
#  supplied_by_user_id                         :bigint
#  vaccine_id                                  :bigint
#
# Indexes
#
#  idx_on_duplicate_of_vaccination_record_id_5071adce87            (duplicate_of_vaccination_record_id)
#  idx_on_patient_id_programme_type_outcome_453b557b54             (patient_id,programme_type,outcome) WHERE (discarded_at IS NULL)
#  index_vaccination_records_on_discarded_at                       (discarded_at)
#  index_vaccination_records_on_location_id                        (location_id)
#  index_vaccination_records_on_next_dose_delay_triage_id          (next_dose_delay_triage_id)
#  index_vaccination_records_on_nhs_immunisations_api_id           (nhs_immunisations_api_id) UNIQUE
#  index_vaccination_records_on_patient_id                         (patient_id)
#  index_vaccination_records_on_patient_id_and_session_id          (patient_id,session_id)
#  index_vaccination_records_on_pending_changes_not_empty          (id) WHERE (pending_changes <> '{}'::jsonb)
#  index_vaccination_records_on_performed_by_user_id               (performed_by_user_id)
#  index_vaccination_records_on_performed_ods_code_and_patient_id  (performed_ods_code,patient_id) WHERE (session_id IS NULL)
#  index_vaccination_records_on_programme_type                     (programme_type)
#  index_vaccination_records_on_reported_by_id                     (reported_by_id)
#  index_vaccination_records_on_session_id                         (session_id)
#  index_vaccination_records_on_supplied_by_user_id                (supplied_by_user_id)
#  index_vaccination_records_on_uuid                               (uuid) UNIQUE
#  index_vaccination_records_on_vaccine_id                         (vaccine_id)
#
# Foreign Keys
#
#  fk_rails_...  (duplicate_of_vaccination_record_id => vaccination_records.id)
#  fk_rails_...  (next_dose_delay_triage_id => triages.id)
#  fk_rails_...  (patient_id => patients.id)
#  fk_rails_...  (performed_by_user_id => users.id)
#  fk_rails_...  (reported_by_id => users.id)
#  fk_rails_...  (session_id => sessions.id)
#  fk_rails_...  (supplied_by_user_id => users.id)
#  fk_rails_...  (vaccine_id => vaccines.id)
#
describe VaccinationRecord do
  subject(:vaccination_record) { build(:vaccination_record) }

  it_behaves_like "a Confirmable model"

  describe "associations" do
    it { should have_one(:identity_check).autosave(true).dependent(:destroy) }
    it { should belong_to(:supplied_by).optional }
  end

  describe "validations" do
    it { should validate_inclusion_of(:protocol).in_array(%w[pgd psd]) }

    context "when administered" do
      before { vaccination_record.outcome = "administered" }

      it { should allow_values(true, false).for(:full_dose) }
      it { should_not allow_values(nil).for(:full_dose) }

      context "when administered in mavis" do
        before { vaccination_record.source = :service }

        it { should validate_presence_of(:protocol) }
        it { should validate_presence_of(:vaccine_id) }
        it { should validate_presence_of(:batch_number) }
        it { should validate_presence_of(:batch_expiry) }
      end
    end

    context "when not administered" do
      before { vaccination_record.outcome = "already_had" }

      it { should_not validate_presence_of(:protocol) }
      it { should_not validate_presence_of(:vaccine_id) }
      it { should_not validate_presence_of(:batch_number) }
      it { should_not validate_presence_of(:batch_expiry) }

      it { should_not validate_presence_of(:full_dose) }
    end

    context "for a school session" do
      subject(:vaccination_record) do
        build(:vaccination_record, programme:, session:)
      end

      let(:programme) { Programme.sample }
      let(:session) { create(:session, programmes: [programme]) }

      it { should validate_absence_of(:location_name) }
    end

    context "for a generic clinic" do
      subject(:vaccination_record) do
        build(:vaccination_record, programme:, session:)
      end

      let(:programme) { Programme.sample }
      let(:team) { create(:team, programmes: [programme]) }
      let(:session) do
        create(
          :session,
          team:,
          location: team.generic_clinic,
          programmes: [programme]
        )
      end

      it { should validate_presence_of(:location_name) }
    end

    context "when performed_at is not set" do
      let(:vaccination_record) { build(:vaccination_record, performed_at: nil) }

      it { should be_valid }
    end

    context "when performed_at is in the future" do
      around { |example| freeze_time { example.run } }

      let(:vaccination_record) do
        build(:vaccination_record, performed_at: 1.day.from_now)
      end

      it "has an error" do
        expect(vaccination_record).to be_invalid
        expect(vaccination_record.errors[:performed_at_date]).to include(
          "Enter a date in the past"
        )
      end
    end
  end

  describe "#programme" do
    subject { vaccination_record.programme }

    context "for an MMRV vaccine" do
      let(:programme) { Programme.mmr }
      let(:vaccine) { Vaccine.find_by!(brand: "ProQuad") }

      let(:vaccination_record) do
        create(:vaccination_record, programme:, vaccine:)
      end

      its(:name) { should eq("MMRV") }
    end

    context "for an MMRV vaccination record without a vaccine" do
      let(:programme) { Programme.mmr }
      let(:disease_types) { %w[measles mumps rubella varicella] }

      let(:vaccination_record) do
        create(:vaccination_record, programme:, disease_types:, vaccine: nil)
      end

      its(:name) { should eq("MMRV") }
    end
  end

  describe "#dose_volume_ml" do
    subject { vaccination_record.dose_volume_ml }

    let(:programme) { Programme.sample }

    let(:vaccine) { build(:vaccine, programme:, dose_volume_ml: 10) }

    context "when administered" do
      let(:vaccination_record) do
        build(:vaccination_record, programme:, vaccine:)
      end

      it { should eq(10) }
    end

    context "when not administered" do
      let(:vaccination_record) do
        build(:vaccination_record, :not_administered, programme:)
      end

      it { should be_nil }
    end

    context "with a half dose" do
      let(:vaccination_record) do
        build(:vaccination_record, :half_dose, programme:, vaccine:)
      end

      it { should eq(5) }
    end
  end

  describe "#performed_by" do
    subject(:performed_by) { vaccination_record.performed_by }

    context "with a user" do
      let(:user) { create(:user, given_name: "John", family_name: "Smith") }
      let(:vaccination_record) do
        create(:vaccination_record, performed_by: user)
      end

      it { should eq(user) }
    end

    context "without a user but with a name" do
      let(:vaccination_record) do
        create(
          :vaccination_record,
          :performed_by_not_user,
          performed_by_given_name: "John",
          performed_by_family_name: "Smith"
        )
      end

      it { should_not be_nil }

      it do
        expect(performed_by).to have_attributes(
          given_name: "John",
          family_name: "Smith",
          full_name: "SMITH, John"
        )
      end
    end

    context "without a user or a name" do
      let(:vaccination_record) do
        create(:vaccination_record, performed_by: nil)
      end

      it { should be_nil }
    end
  end

  describe "#performed_at" do
    subject { vaccination_record.performed_at }

    context "with only a date" do
      let(:vaccination_record) do
        create(
          :vaccination_record,
          performed_at_date: "2020-01-01",
          performed_at_time: nil
        )
      end

      it { should eq(Date.new(2020, 1, 1)) }
    end

    context "with a date and a time" do
      let(:vaccination_record) do
        create(
          :vaccination_record,
          performed_at_date: "2020-01-01",
          performed_at_time: "12:30"
        )
      end

      it { should eq(Time.zone.local(2020, 1, 1, 12, 30)) }
    end
  end

  describe "#performed_at=" do
    let(:vaccination_record) { build(:vaccination_record, performed_at: nil) }

    it "sets the performed at date and time columns" do
      performed_at = Time.zone.local(2020, 1, 1, 12, 30)

      expected_date = Date.new(2020, 1, 1)

      # Although we store the value in the database as just the time, Ruby
      #  doesn't have an object that can hold just time information. Instead,
      #  we get back a `Time` object with the date set to 2020-01-01.
      expected_time = Time.zone.local(2000, 1, 1, 12, 30)

      expect { vaccination_record.performed_at = performed_at }.to change(
        vaccination_record,
        :performed_at_date
      ).to(expected_date).and change(vaccination_record, :performed_at_time).to(
              expected_time
            )
    end

    it "sets the time correctly for daylight saving" do
      performed_at = Time.zone.local(2020, 8, 1, 12, 30)

      expected_date = Date.new(2020, 8, 1)
      expected_time = Time.zone.local(2000, 1, 1, 12, 30)

      expect { vaccination_record.performed_at = performed_at }.to change(
        vaccination_record,
        :performed_at_date
      ).to(expected_date).and change(vaccination_record, :performed_at_time).to(
              expected_time
            )
    end
  end

  describe "#show_in_academic_year?" do
    subject { vaccination_record.show_in_academic_year?(academic_year) }

    context "with a seasonal record performed in the 2023/24 academic year" do
      let(:programme) { Programme.flu }
      let(:vaccination_record) do
        build(
          :vaccination_record,
          programme:,
          performed_at: Time.zone.local(2023, 9, 1)
        )
      end

      context "in the 2023/24 academic year" do
        let(:academic_year) { 2023 }

        it { should be(true) }
      end

      context "in the 2024/25 academic year" do
        let(:academic_year) { 2024 }

        it { should be(false) }
      end
    end

    context "with a non-seasonal record performed in the 2023/24 academic year" do
      let(:programme) { Programme.hpv }
      let(:vaccination_record) do
        build(
          :vaccination_record,
          programme:,
          performed_at: Time.zone.local(2023, 9, 1)
        )
      end

      context "in the 2023/24 academic year" do
        let(:academic_year) { 2023 }

        it { should be(true) }
      end

      context "in the 2024/25 academic year" do
        let(:academic_year) { 2024 }

        it { should be(true) }
      end
    end
  end

  describe "#delivery_method_snomed_code" do
    subject(:delivery_method_snomed_code) do
      vaccination_record.delivery_method_snomed_code
    end

    context "when delivery_method is intramuscular" do
      let(:vaccination_record) do
        build(:vaccination_record, delivery_method: :intramuscular)
      end

      it { should eq "78421000" }
    end

    context "when delivery_method is subcutaneous" do
      let(:vaccination_record) do
        build(:vaccination_record, delivery_method: :subcutaneous)
      end

      it { should eq "34206005" }
    end

    context "when delivery_method is nasal spray" do
      let(:vaccination_record) do
        build(:vaccination_record, delivery_method: :nasal_spray)
      end

      it { should eq "46713006" }
    end

    context "when delivery_method is not set" do
      let(:vaccination_record) do
        build(:vaccination_record, delivery_method: nil)
      end

      it "raises an error" do
        expect { delivery_method_snomed_code }.to raise_error(StandardError)
      end
    end
  end

  describe "#delivery_method_snomed_term" do
    subject(:delivery_method_snomed_term) do
      vaccination_record.delivery_method_snomed_term
    end

    context "when delivery_method is intramuscular" do
      let(:vaccination_record) do
        build(:vaccination_record, delivery_method: :intramuscular)
      end

      it { should eq "Intramuscular" }
    end

    context "when delivery_method is subcutaneous" do
      let(:vaccination_record) do
        build(:vaccination_record, delivery_method: :subcutaneous)
      end

      it { should eq "Subcutaneous" }
    end

    context "when delivery_method is nasal spray" do
      let(:vaccination_record) do
        build(:vaccination_record, delivery_method: :nasal_spray)
      end

      it { should eq "Nasal" }
    end

    context "when delivery_method is not set" do
      let(:vaccination_record) do
        build(:vaccination_record, delivery_method: nil)
      end

      it "raises an error" do
        expect { delivery_method_snomed_term }.to raise_error(StandardError)
      end
    end
  end

  describe "#for_academic_year" do
    before { vaccination_record.save! }

    it "returns the correct records" do
      academic_year = vaccination_record.academic_year

      expect(described_class.for_academic_year(academic_year)).to include(
        vaccination_record
      )

      expect(
        described_class.for_academic_year(academic_year + 1)
      ).not_to include(vaccination_record)
    end
  end

  describe "#academic_year" do
    let(:examples) do
      {
        Date.new(2020, 9, 1) => 2020,
        Date.new(2021, 8, 31) => 2020,
        Date.new(2021, 9, 1) => 2021,
        Date.new(2022, 8, 31) => 2021
      }
    end

    examples.each do |date, academic_year|
      context "with #{date}" do
        before { vaccination_record[attribute] = date }

        it { expect(vaccination_record.academic_year).to eq(academic_year) }
      end
    end
  end
end
