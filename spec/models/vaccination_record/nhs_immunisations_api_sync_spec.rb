# frozen_string_literal: true

describe VaccinationRecord::NHSImmunisationsAPISync do
  let(:vaccination_record) do
    build(:vaccination_record, outcome:, programme:, session:)
  end
  let(:outcome) { "administered" }
  let(:programme) { Programme.flu }
  let(:session) { create(:session, programmes: [programme]) }

  describe "#sync_to_nhs_immunisations_api!" do
    before { Flipper.enable(:imms_api_sync_job, programme) }

    it "enqueues the job if the vaccination record is eligible to sync" do
      expect {
        vaccination_record.sync_to_nhs_immunisations_api!
      }.to enqueue_sidekiq_job(SyncVaccinationRecordToNHSJob)
    end

    it "sets nhs_immunisations_api_sync_pending_at" do
      freeze_time do
        expect { vaccination_record.sync_to_nhs_immunisations_api! }.to change(
          vaccination_record,
          :nhs_immunisations_api_sync_pending_at
        ).from(nil).to(Time.current)
      end
    end

    context "when the vaccination record isn't syncable" do
      before do
        allow(vaccination_record).to receive(
          :correct_source_for_nhs_immunisations_api?
        ).and_return(false)
      end

      it "does not enqueue the job" do
        expect {
          vaccination_record.sync_to_nhs_immunisations_api!
        }.not_to enqueue_sidekiq_job(SyncVaccinationRecordToNHSJob)
      end

      it "does not set nhs_immunisations_api_sync_pending_at" do
        expect {
          vaccination_record.sync_to_nhs_immunisations_api!
        }.not_to change(
          vaccination_record,
          :nhs_immunisations_api_sync_pending_at
        )
      end
    end

    context "when the feature flag is disabled" do
      before { Flipper.disable(:imms_api_sync_job) }

      let(:vaccination_record) { create(:vaccination_record) }

      it "does not enqueue the job" do
        expect {
          vaccination_record.sync_to_nhs_immunisations_api!
        }.not_to enqueue_sidekiq_job(SyncVaccinationRecordToNHSJob)
      end

      it "does not set nhs_immunisations_api_sync_pending_at" do
        expect {
          vaccination_record.sync_to_nhs_immunisations_api!
        }.not_to change(
          vaccination_record,
          :nhs_immunisations_api_sync_pending_at
        )
      end
    end
  end

  describe "with_correct_source_for_nhs_immunisations_api scope" do
    subject { VaccinationRecord.with_correct_source_for_nhs_immunisations_api }

    before { Flipper.enable(:sync_national_reporting_to_imms_api) }

    let!(:vaccination_record) do
      create(:vaccination_record, programme:, session:)
    end
    let!(:vaccination_record_outside_of_session) do
      create(:vaccination_record, programme:)
    end

    it { should include(vaccination_record) }
    it { should_not include(vaccination_record_outside_of_session) }

    context "when vaccination record was uploaded through national reporting portal" do
      let!(:vaccination_record) do
        create(
          :vaccination_record,
          :sourced_from_national_reporting,
          programme:
        )
      end

      it { should include(vaccination_record) }

      context "with the sync_national_reporting_to_imms_api feature flag disabled" do
        before { Flipper.disable(:sync_national_reporting_to_imms_api) }

        let!(:vaccination_record) do
          create(
            :vaccination_record,
            :sourced_from_national_reporting,
            programme:
          )
        end

        it { should_not include(vaccination_record) }
      end
    end

    context "when vaccination record was part of a historical upload" do
      let!(:vaccination_record) do
        create(:vaccination_record, source: :historical_upload, programme:)
      end

      it { should_not include(vaccination_record) }
    end

    context "a vaccination record created because patient is already vaccinated" do
      let!(:vaccination_record) do
        create(:vaccination_record, source: :consent_refusal, programme:)
      end

      it { should_not include(vaccination_record) }
    end
  end

  describe "#correct_source_to_nhs_immunisations_api?" do
    subject { vaccination_record.correct_source_for_nhs_immunisations_api? }

    before { Flipper.enable(:sync_national_reporting_to_imms_api) }

    context "when the vaccination record is eligible to sync" do
      it { should be true }
    end

    context "a discarded vaccination record" do
      before { vaccination_record.discard! }

      it { should be true }
    end

    context "a vaccination record not recorded in Mavis" do
      let(:session) { nil }

      it { should be false }
    end

    context "a vaccination record uploaded through national reporting portal" do
      let(:vaccination_record) do
        build(
          :vaccination_record,
          :sourced_from_national_reporting,
          outcome:,
          programme:
        )
      end

      it { should be true }

      context "with the sync_national_reporting_to_imms_api feature flag disabled" do
        before { Flipper.disable(:sync_national_reporting_to_imms_api) }

        it { should be false }
      end
    end

    context "a vaccination record created because patient is already vaccinated" do
      let(:vaccination_record) do
        build(
          :vaccination_record,
          source: :consent_refusal,
          outcome:,
          programme:
        )
      end

      it { should be false }
    end

    context "a patient without an nhs number" do
      let(:patient) do
        create(:patient, nhs_number: nil, school: session.location)
      end
      let(:vaccination_record) do
        create(:vaccination_record, outcome:, programme:, session:, patient:)
      end

      it { should be true }
    end

    VaccinationRecord.defined_enums["outcome"].each_key do |outcome|
      next if outcome == "administered"

      context "when the vaccination record outcome is #{outcome}" do
        let(:outcome) { outcome }

        it { should be true }
      end
    end

    Programme::TYPES.each do |programme_type|
      next if programme_type.in?(%i[flu hpv])

      context "when the programme type is #{programme_type}" do
        let(:programme) { Programme.find(programme_type) }

        it { should be true }
      end
    end
  end

  describe "#sync_status" do
    subject(:sync_status) { vaccination_record.sync_status }

    before { Flipper.enable(:imms_api_sync_job, programme) }

    context "when patient has no NHS number" do
      let(:patient) do
        create(:patient, nhs_number: nil, school: session.location)
      end

      let(:vaccination_record) do
        create(:vaccination_record, outcome:, programme:, session:, patient:)
      end

      context "record needs to be synced" do
        before do
          vaccination_record.update!(
            nhs_immunisations_api_sync_pending_at: Time.current,
            nhs_immunisations_api_id: nil
          )
        end

        it "returns :pending" do
          expect(sync_status).to eq(:pending)
        end
      end

      context "when record has been synced successfully" do
        before do
          vaccination_record.update!(
            nhs_immunisations_api_sync_pending_at: 2.hours.ago,
            nhs_immunisations_api_synced_at: 1.hour.ago
          )
        end

        it "returns :synced" do
          expect(sync_status).to eq(:synced)
        end
      end
    end

    context "when record has been synced successfully" do
      before do
        vaccination_record.update!(
          nhs_immunisations_api_sync_pending_at: 2.hours.ago,
          nhs_immunisations_api_synced_at: 1.hour.ago
        )
      end

      it "returns :synced" do
        expect(sync_status).to eq(:synced)
      end
    end

    context "when sync has been pending for less than 24 hours" do
      before do
        vaccination_record.update!(
          nhs_immunisations_api_sync_pending_at: 23.hours.ago,
          nhs_immunisations_api_synced_at: nil
        )
      end

      it "returns :pending" do
        expect(sync_status).to eq(:pending)
      end
    end

    context "when sync has been pending for more than 24 hours" do
      before do
        vaccination_record.update!(
          nhs_immunisations_api_sync_pending_at: 25.hours.ago,
          nhs_immunisations_api_synced_at: nil
        )
      end

      it "returns :failed" do
        expect(sync_status).to eq(:failed)
      end
    end

    context "when sync has been pending for more than 24 hours, and has been synced before" do
      before do
        vaccination_record.update!(
          nhs_immunisations_api_sync_pending_at: 25.hours.ago,
          nhs_immunisations_api_synced_at: 2.days.ago
        )
      end

      it "returns :failed" do
        expect(sync_status).to eq(:failed)
      end
    end

    context "when record was not administered" do
      before do
        vaccination_record.update!(
          nhs_immunisations_api_sync_pending_at: nil,
          nhs_immunisations_api_synced_at: nil
        )

        allow(vaccination_record).to receive(:administered?).and_return(false)
      end

      it "returns :not_synced" do
        expect(sync_status).to eq(:not_synced)
      end
    end

    context "when record was marked as already vaccinated" do
      let(:outcome) { :already_had }

      before do
        vaccination_record.update!(
          nhs_immunisations_api_sync_pending_at: nil,
          nhs_immunisations_api_synced_at: nil
        )
      end

      it "returns :not_synced" do
        expect(sync_status).to eq(:not_synced)
      end
    end

    context "when record was a historic vaccination" do
      let(:session) { nil }

      before do
        vaccination_record.update!(
          nhs_immunisations_api_sync_pending_at: nil,
          nhs_immunisations_api_synced_at: nil
        )
      end

      it "returns :not_synced" do
        expect(sync_status).to eq(:not_synced)
      end
    end

    context "when record has not been synced yet, but will eventually be" do
      before do
        vaccination_record.update!(
          nhs_immunisations_api_sync_pending_at: nil,
          nhs_immunisations_api_synced_at: nil
        )
      end

      it "returns :pending" do
        expect(sync_status).to eq(:pending)
      end
    end

    context "when record is pending removal from API because changed to not administered" do
      before do
        vaccination_record.update!(
          nhs_immunisations_api_sync_pending_at: 1.hour.ago,
          nhs_immunisations_api_synced_at: 1.day.ago
        )

        allow(vaccination_record).to receive(:administered?).and_return(false)
      end

      it "returns :not_synced" do
        expect(sync_status).to eq(:not_synced)
      end
    end

    context "when record has been successfully removed from API, after being changed to not administered" do
      before do
        vaccination_record.update!(
          nhs_immunisations_api_sync_pending_at: 2.hours.ago,
          nhs_immunisations_api_synced_at: 1.hour.ago
        )

        allow(vaccination_record).to receive(:administered?).and_return(false)
      end

      it "returns :not_synced" do
        expect(sync_status).to eq(:not_synced)
      end
    end

    context "when record has been unsuccessfully removed from API, after being changed to not administered" do
      before do
        vaccination_record.update!(
          nhs_immunisations_api_sync_pending_at: 25.hours.ago,
          nhs_immunisations_api_synced_at: 2.days.ago
        )

        allow(vaccination_record).to receive(:administered?).and_return(false)
      end

      it "returns :not_synced" do
        expect(sync_status).to eq(:not_synced)
      end
    end

    context "when the sync job feature flag has a different programme enabled" do
      before do
        Flipper.disable(:imms_api_sync_job)
        Flipper.enable(:imms_api_sync_job, Programme.mmr)
      end

      it "returns `not_synced`" do
        expect(sync_status).to eq(:not_synced)
      end
    end
  end

  describe "#should_be_in_nhs_immunisations_api?" do
    subject { vaccination_record.should_be_in_nhs_immunisations_api? }

    let(:patient) { create(:patient, session:) }
    let(:notify_parents) { true }
    let(:vaccination_record) do
      create(
        :vaccination_record,
        outcome:,
        programme:,
        session:,
        patient:,
        notify_parents:
      )
    end

    before { Flipper.enable(:imms_api_sync_job, programme) }

    context "when all conditions are met" do
      it { should be true }
    end

    context "when the vaccination record has been discarded" do
      before { vaccination_record.discard! }

      it { should be false }
    end

    context "when the vaccination record doesn't have the correct source" do
      before do
        allow(vaccination_record).to receive(
          :correct_source_for_nhs_immunisations_api?
        ).and_return(false)
      end

      it { should be false }
    end

    VaccinationRecord.defined_enums["outcome"].each_key do |outcome|
      next if outcome == "administered"

      context "the vaccination record outcome is #{outcome}" do
        let(:vaccination_record) do
          create(:vaccination_record, outcome:, programme:, session:, patient:)
        end

        it { should be false }
      end
    end

    context "when the patient has no NHS number" do
      before { patient.update(nhs_number: nil) }

      it { should be true }
    end

    context "when the patient has requested that their parents aren't notified" do
      let(:notify_parents) { false }

      it { should be false }
    end

    context "when notify_parents is not set" do
      let(:notify_parents) { nil }

      it { should be true }
    end

    context "when the patient is invalidated" do
      before { patient.update(invalidated_at: Time.current) }

      it { should be false }
    end

    context "when the programme type is not enabled in the feature flag" do
      let(:programme) { Programme.menacwy }

      before do
        Flipper.disable(:imms_api_sync_job)
        Flipper.enable(:imms_api_sync_job, Programme.hpv)
      end

      it { should be false }
    end
  end
end
