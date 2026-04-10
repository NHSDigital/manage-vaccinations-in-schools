# frozen_string_literal: true

# == Schema Information
#
# Table name: patient_programme_statuses
#
#  id                      :bigint           not null, primary key
#  academic_year           :integer          not null
#  consent_status          :integer          default("no_response"), not null
#  consent_vaccine_methods :integer          default([]), not null, is an Array
#  date                    :date
#  disease_types           :enum             is an Array
#  dose_sequence           :integer
#  programme_type          :enum             not null
#  status                  :integer          default("not_eligible"), not null
#  vaccine_methods         :integer          is an Array
#  without_gelatine        :boolean
#  location_id             :bigint
#  patient_id              :bigint           not null
#
# Indexes
#
#  idx_on_academic_year_patient_id_3d5bf8d2c8                 (academic_year,patient_id)
#  idx_on_patient_id_academic_year_programme_type_75e0e0c471  (patient_id,academic_year,programme_type) UNIQUE
#  index_patient_programme_statuses_on_location_id            (location_id)
#  index_patient_programme_statuses_on_patient_id             (patient_id)
#  index_patient_programme_statuses_on_status                 (status)
#
# Foreign Keys
#
#  fk_rails_...  (patient_id => patients.id) ON DELETE => cascade
#
describe Patient::ProgrammeStatus do
  subject(:patient_programme_status) { build(:patient_programme_status) }

  describe "associations" do
    it { should belong_to(:patient) }
  end

  describe "#needs_more_doses?" do
    subject(:needs_more_doses) do
      patient.programme_status(
        Programme.mmr,
        academic_year: session.academic_year
      ).needs_more_doses?
    end

    let(:programme) { Programme.mmr }
    let(:team) { create(:team, programmes: [programme]) }
    let(:session) do
      create(
        :session,
        team:,
        programmes: [programme],
        date: Date.new(2024, 10, 1)
      )
    end
    let(:patient) { create(:patient, session:, year_group: 9) }

    context "with no vaccinations" do
      before { PatientStatusUpdater.call(patient:) }

      it { should be(true) }
    end

    context "with one vaccination" do
      before do
        create(
          :vaccination_record,
          :administered,
          programme:,
          patient:,
          session:,
          performed_at: Date.new(2024, 10, 1)
        )
        PatientStatusUpdater.call(patient:)
      end

      it { should be(true) }
    end

    context "with two vaccinations" do
      before do
        create(
          :vaccination_record,
          :administered,
          programme:,
          patient:,
          session:,
          performed_at: Date.new(2024, 10, 1)
        )
        create(
          :vaccination_record,
          :administered,
          programme:,
          patient:,
          session:,
          performed_at: Date.new(2024, 11, 1)
        )
        PatientStatusUpdater.call(patient:)
      end

      it { should be(false) }
    end
  end

  describe "#assign" do
    subject(:assign) { patient_programme_status.assign }

    let(:programme_generator) { instance_double(StatusGenerator::Programme) }

    before do
      allow(StatusGenerator::Programme).to receive(:new).and_return(
        programme_generator
      )
      allow(programme_generator).to receive_messages(
        consent_status: :given,
        consent_vaccine_methods: %w[injection],
        date: Date.new(2020, 1, 1),
        disease_types: %w[influenza],
        dose_sequence: 1,
        location_id: 1,
        status: :vaccinated_fully,
        vaccine_methods: %w[injection],
        without_gelatine: true
      )
    end

    it "calls the status generator" do
      assign

      expect(patient_programme_status.consent_status).to eq("given")
      expect(patient_programme_status.consent_vaccine_methods).to eq(
        %w[injection]
      )
      expect(patient_programme_status.date).to eq(Date.new(2020, 1, 1))
      expect(patient_programme_status.disease_types).to eq(%w[influenza])
      expect(patient_programme_status.dose_sequence).to eq(1)
      expect(patient_programme_status.location_id).to eq(1)
      expect(patient_programme_status.status).to eq("vaccinated_fully")
      expect(patient_programme_status.vaccine_methods).to eq(%w[injection])
      expect(patient_programme_status.without_gelatine).to be(true)
    end
  end
end
