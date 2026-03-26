# frozen_string_literal: true

describe PatientProgrammeStatusResolver do
  subject(:hash) do
    described_class.call(
      Patient.includes_statuses.find(patient.id),
      programme_type: programme.type,
      academic_year:,
      context_location_id:
    )
  end

  let(:patient) { create(:patient) }
  let(:programme) { Programme.hpv }
  let(:session) { create(:session, programmes: [programme]) }
  let(:academic_year) { AcademicYear.current }
  let(:context_location_id) { nil }

  it { should eq({ prefix: "HPV", text: "Not eligible", colour: "grey" }) }

  context "when triaged to delay vaccination" do
    around { |example| freeze_time(Date.new(2025, 10, 29)) { example.run } }

    let(:patient) do
      create(:patient, :consent_given_triage_delay_vaccination, session:)
    end

    it do
      expect(hash).to eq(
        {
          prefix: "HPV",
          text: "Unable to vaccinate",
          colour: "red",
          details_text: "Delay vaccination until 30 October 2025"
        }
      )
    end
  end

  context "with an administered vaccination record" do
    let(:patient) do
      create(:patient, :consent_given_triage_not_needed, session:)
    end

    before do
      create(
        :vaccination_record,
        :administered,
        patient:,
        programme:,
        performed_at: Time.zone.local(2025, 10, 30)
      )
      PatientStatusUpdater.call(patient:)
      patient.reload
    end

    it do
      expect(hash).to eq(
        {
          prefix: "HPV",
          text: "Vaccinated",
          colour: "white",
          details_text: "Vaccinated on 30 October 2025"
        }
      )
    end
  end

  context "with an already had vaccination record" do
    let(:patient) do
      create(:patient, :consent_given_triage_not_needed, session:)
    end

    before do
      create(:vaccination_record, :already_had, patient:, programme:)
      PatientStatusUpdater.call(patient:)
      patient.reload
    end

    it do
      expect(hash).to eq(
        {
          prefix: "HPV",
          text: "Vaccinated",
          colour: "white",
          details_text: "Already had the vaccine"
        }
      )
    end
  end

  context "and due" do
    let(:patient) do
      create(:patient, :consent_given_triage_not_needed, session:)
    end

    it do
      expect(hash).to eq(
        { prefix: "HPV", text: "Due vaccination", colour: "green" }
      )
    end
  end

  context "for MMR programme" do
    let(:programme) { Programme.mmr }
    let(:programme_variant) do
      Programme::Variant.new(programme, variant_type: "mmr")
    end

    let(:date_of_birth) { Date.new(2019, 12, 31) }

    context "and eligible for 1st dose" do
      let(:patient) { create(:patient, date_of_birth:, session:) }

      before do
        PatientStatusUpdater.call(patient:)
        patient.reload
      end

      it do
        expect(hash).to eq(
          {
            prefix: "MMR",
            text: "Needs consent",
            colour: "blue",
            details_text: "No response"
          }
        )
      end
    end

    context "and due 1st dose" do
      let(:patient) do
        create(
          :patient,
          :consent_given_triage_not_needed,
          date_of_birth:,
          session:,
          programmes: [programme_variant]
        )
      end

      before do
        PatientStatusUpdater.call(patient:)
        patient.reload
      end

      it do
        expect(hash).to eq(
          {
            prefix: "MMR",
            text: "Due 1st dose",
            colour: "green",
            details_text: "No preference"
          }
        )
      end
    end

    context "and due 1st dose gelatine-free" do
      let(:patient) do
        create(
          :patient,
          :consent_given_without_gelatine_triage_not_needed,
          date_of_birth:,
          session:,
          programmes: [programme_variant]
        )
      end

      before do
        PatientStatusUpdater.call(patient:)
        patient.reload
      end

      it do
        expect(hash).to eq(
          {
            prefix: "MMR",
            text: "Due 1st dose",
            colour: "green",
            details_text: "Gelatine-free vaccine only"
          }
        )
      end
    end
  end
end
