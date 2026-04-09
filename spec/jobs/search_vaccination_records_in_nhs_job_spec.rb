# frozen_string_literal: true

describe SearchVaccinationRecordsInNHSJob do
  let(:team) { create(:team) }
  let(:school) { create(:gias_school, team:) }
  let(:patient) { create(:patient, team:, session:, school:, nhs_number:) }
  let(:session) { create(:session, programmes: [programme], location: school) }
  let(:nhs_number) { "9449308357" }
  let!(:programme) { Programme.flu }

  before do
    Flipper.enable(:imms_api_integration)
    Flipper.enable(:imms_api_search_job, programme)
  end

  after do
    Flipper.disable(:imms_api_integration)
    Flipper.disable(:imms_api_search_job)
  end

  describe "#extract_vaccination_records" do
    let(:bundle) do
      FHIR.from_contents(
        file_fixture("fhir/search_responses/2_results.json").read
      )
    end

    it "returns only Immunization resources from the bundle" do
      records =
        described_class.new.send(:extract_fhir_vaccination_records, bundle)
      expect(records).to all(have_attributes(resourceType: "Immunization"))
      expect(records.size).to eq 2
    end
  end

  describe "#select_programme_feature_flagged_records" do
    subject(:selected_records) do
      described_class.new.send(
        :select_programme_feature_flagged_records,
        vaccination_records
      )
    end

    let(:vaccination_records) { [flu_record, hpv_record, mmrv_record] }
    let(:flu_record) { create(:vaccination_record, programme: Programme.flu) }
    let(:hpv_record) { create(:vaccination_record, programme: Programme.hpv) }
    let(:mmrv_programme) do
      Programme::Variant.new(Programme.mmr, variant_type: "mmrv")
    end
    let(:mmrv_record) { create(:vaccination_record, programme: mmrv_programme) }

    before do
      Flipper.disable(:imms_api_search_job)
      Flipper.enable(:imms_api_search_job, Programme.flu)
      Flipper.enable(:imms_api_search_job, Programme.mmr)
    end

    it "rejects the hpv and mmrv records, and keeps the flu record" do
      expect(selected_records).to match_array(flu_record)
    end
  end

  describe "#reject_service_sourced_records" do
    subject(:reject_service_sourced) do
      described_class.new.send(
        :reject_service_sourced_records,
        vaccination_records
      )
    end

    let(:service_record) do
      build(
        :vaccination_record,
        :sourced_from_nhs_immunisations_api,
        nhs_immunisations_api_identifier_system:
          FHIRMapper::VaccinationRecord::MAVIS_SYSTEM_NAME
      )
    end
    let(:national_reporting_record) do
      build(
        :vaccination_record,
        :sourced_from_nhs_immunisations_api,
        nhs_immunisations_api_identifier_system:
          FHIRMapper::VaccinationRecord::MAVIS_NATIONAL_REPORTING_SYSTEM_NAME
      )
    end
    let(:third_party_record) do
      build(
        :vaccination_record,
        :sourced_from_nhs_immunisations_api,
        nhs_immunisations_api_identifier_system: "SomeOtherSystem"
      )
    end

    let(:vaccination_records) do
      [service_record, national_reporting_record, third_party_record]
    end

    it "keeps only records with a third-party identifier system" do
      expect(reject_service_sourced).to contain_exactly(third_party_record)
    end
  end

  describe "#deduplicate_vaccination_records" do
    subject(:deduplicate) do
      described_class
        .new
        .tap { it.instance_variable_set(:@patient, patient) }
        .send(:deduplicate_vaccination_records, vaccination_records)
    end

    shared_examples "handles duplicates" do
      context "both primary source" do
        let(:nhs_immunisations_api_primary_source) { true }

        it "returns both records" do
          expect(deduplicate).to contain_exactly(
            first_vaccination_record,
            second_vaccination_record
          )
        end

        it "does not discard either record" do
          deduplicate
          expect(first_vaccination_record.discarded_at).to be_nil
          expect(second_vaccination_record.discarded_at).to be_nil
        end
      end

      context "one primary source" do
        let(:nhs_immunisations_api_primary_source) { false }

        it "returns both records" do
          expect(deduplicate).to contain_exactly(
            first_vaccination_record,
            second_vaccination_record
          )
        end

        it "discards the non-primary-source record" do
          deduplicate
          expect(second_vaccination_record.discarded_at).not_to be_nil
        end

        it "does not discard the primary source record" do
          deduplicate
          expect(first_vaccination_record.discarded_at).to be_nil
        end

        it "points the non-primary-source record at the primary source record" do
          deduplicate
          expect(
            second_vaccination_record.duplicate_of_vaccination_record
          ).to eq(first_vaccination_record)
        end
      end

      context "neither primary source" do
        let(:nhs_immunisations_api_primary_source) { false }
        let(:first_primary_source) { false }

        it "returns both records" do
          expect(deduplicate).to contain_exactly(
            first_vaccination_record,
            second_vaccination_record
          )
        end

        it "does not discard either record" do
          deduplicate
          expect(first_vaccination_record.discarded_at).to be_nil
          expect(second_vaccination_record.discarded_at).to be_nil
        end
      end

      context "record duplicates a Mavis record" do
        let(:nhs_immunisations_api_primary_source) { true }
        let!(:mavis_record) do
          create(
            :vaccination_record,
            session:,
            programme:,
            patient:,
            performed_at:
          )
        end

        it "returns all incoming records" do
          expect(deduplicate).to contain_exactly(
            first_vaccination_record,
            second_vaccination_record
          )
        end

        it "discards all incoming records" do
          deduplicate
          expect(first_vaccination_record.discarded_at).not_to be_nil
          expect(second_vaccination_record.discarded_at).not_to be_nil
        end

        it "points all incoming records at the Mavis record" do
          deduplicate
          expect(
            first_vaccination_record.duplicate_of_vaccination_record
          ).to eq(mavis_record)
          expect(
            second_vaccination_record.duplicate_of_vaccination_record
          ).to eq(mavis_record)
        end
      end
    end

    let(:vaccination_records) do
      [
        first_vaccination_record,
        second_vaccination_record,
        third_vaccination_record
      ].compact
    end

    let(:first_vaccination_record) do
      build(
        :vaccination_record,
        :sourced_from_nhs_immunisations_api,
        programme:,
        patient:,
        nhs_immunisations_api_primary_source: first_primary_source,
        performed_at:
      )
    end
    let(:first_primary_source) { true }

    let(:performed_at) { Time.zone.local(2025, 10, 10) }

    let(:second_vaccination_record) { nil }

    let(:third_vaccination_record) { nil }

    context "with a single vaccination record" do
      it "returns the record" do
        expect(deduplicate).to eq [first_vaccination_record]
      end
    end

    context "with two vaccination records with the same programme and performed_at" do
      let(:second_vaccination_record) do
        build(
          :vaccination_record,
          :sourced_from_nhs_immunisations_api,
          programme:,
          patient:,
          nhs_immunisations_api_primary_source:,
          performed_at:
        )
      end

      include_examples "handles duplicates"
    end

    context "with the same programme and performed_at on the same day" do
      let(:second_vaccination_record) do
        build(
          :vaccination_record,
          :sourced_from_nhs_immunisations_api,
          programme:,
          patient:,
          nhs_immunisations_api_primary_source:,
          performed_at: Time.zone.local(2025, 10, 10, 12, 33, 44)
        )
      end

      include_examples "handles duplicates"
    end

    context "with the same programme and different performed_at" do
      let(:second_vaccination_record) do
        build(
          :vaccination_record,
          :sourced_from_nhs_immunisations_api,
          programme:,
          patient:,
          nhs_immunisations_api_primary_source: false,
          performed_at: Time.zone.local(2025, 10, 9)
        )
      end

      it "returns both records" do
        expect(deduplicate).to contain_exactly(
          second_vaccination_record,
          first_vaccination_record
        )
      end
    end

    context "with different programmes, same performed_at" do
      let(:second_vaccination_record) do
        build(
          :vaccination_record,
          :sourced_from_nhs_immunisations_api,
          programme: Programme.hpv,
          patient:,
          nhs_immunisations_api_primary_source: false,
          performed_at:
        )
      end

      it "returns both records" do
        expect(deduplicate).to contain_exactly(
          first_vaccination_record,
          second_vaccination_record
        )
      end
    end

    context "with three duplicate records" do
      let(:second_vaccination_record) do
        build(
          :vaccination_record,
          :sourced_from_nhs_immunisations_api,
          programme:,
          patient:,
          nhs_immunisations_api_primary_source: second_primary_source,
          performed_at:
        )
      end

      let(:third_vaccination_record) do
        build(
          :vaccination_record,
          :sourced_from_nhs_immunisations_api,
          programme:,
          patient:,
          nhs_immunisations_api_primary_source: third_primary_source,
          performed_at:
        )
      end

      context "with one primary source" do
        let(:second_primary_source) { false }
        let(:third_primary_source) { false }

        it "returns all three records" do
          expect(deduplicate).to contain_exactly(
            first_vaccination_record,
            second_vaccination_record,
            third_vaccination_record
          )
        end

        it "discards the non-primary-source records" do
          deduplicate
          expect(second_vaccination_record.discarded_at).not_to be_nil
          expect(third_vaccination_record.discarded_at).not_to be_nil
        end

        it "does not discard the primary source record" do
          deduplicate
          expect(first_vaccination_record.discarded_at).to be_nil
        end
      end

      context "with two primary sources" do
        let(:second_primary_source) { true }
        let(:third_primary_source) { false }

        it "returns all three records" do
          expect(deduplicate).to contain_exactly(
            first_vaccination_record,
            second_vaccination_record,
            third_vaccination_record
          )
        end

        it "discards the non-primary-source record" do
          deduplicate
          expect(third_vaccination_record.discarded_at).not_to be_nil
        end

        it "does not discard the primary source records" do
          deduplicate
          expect(first_vaccination_record.discarded_at).to be_nil
          expect(second_vaccination_record.discarded_at).to be_nil
        end
      end

      context "with three primary sources" do
        let(:second_primary_source) { true }
        let(:third_primary_source) { true }

        it "returns all three records" do
          expect(deduplicate).to contain_exactly(
            first_vaccination_record,
            second_vaccination_record,
            third_vaccination_record
          )
        end

        it "does not discard any record" do
          deduplicate
          expect(first_vaccination_record.discarded_at).to be_nil
          expect(second_vaccination_record.discarded_at).to be_nil
          expect(third_vaccination_record.discarded_at).to be_nil
        end
      end
    end

    context "with a pair of duplicates and an unrelated record" do
      shared_examples "contains the unrelated record" do
        context "when the unrelated record is not primary" do
          let(:third_primary_source) { false }

          it "returns the unrelated record" do
            expect(deduplicate).to include(third_vaccination_record)
          end
        end

        context "when the unrelated record is primary" do
          let(:third_primary_source) { true }

          it "returns the unrelated record" do
            expect(deduplicate).to include(third_vaccination_record)
          end
        end
      end

      let(:second_vaccination_record) do
        build(
          :vaccination_record,
          :sourced_from_nhs_immunisations_api,
          programme:,
          patient:,
          nhs_immunisations_api_primary_source: second_primary_source,
          performed_at:
        )
      end

      let(:third_vaccination_record) do
        build(
          :vaccination_record,
          :sourced_from_nhs_immunisations_api,
          programme: Programme.hpv,
          patient:,
          nhs_immunisations_api_primary_source: third_primary_source,
          performed_at: Time.zone.local(2025, 10, 9)
        )
      end
      let(:third_primary_source) { true }

      context "both primary source" do
        let(:second_primary_source) { true }

        it "returns both records" do
          expect(deduplicate).to include(
            first_vaccination_record,
            second_vaccination_record
          )
        end

        include_examples "contains the unrelated record"
      end

      context "one primary source" do
        let(:second_primary_source) { false }

        it "returns the primary and non-primary source records" do
          expect(deduplicate).to include(
            first_vaccination_record,
            second_vaccination_record
          )
        end

        it "discards the non-primary-source record" do
          deduplicate
          expect(second_vaccination_record.discarded_at).not_to be_nil
        end

        it "does not discard the primary source record" do
          deduplicate
          expect(first_vaccination_record.discarded_at).to be_nil
        end

        include_examples "contains the unrelated record"
      end

      context "neither primary source" do
        let(:second_primary_source) { false }
        let(:first_primary_source) { false }

        it "returns both records" do
          expect(deduplicate).to include(
            first_vaccination_record,
            second_vaccination_record
          )
        end

        include_examples "contains the unrelated record"
      end
    end

    context "with no vaccination_records" do
      let(:vaccination_records) { [] }

      it "returns an empty array" do
        expect(deduplicate).to eq([])
      end
    end

    context "with an existing Mavis record" do
      before do
        create(
          :vaccination_record,
          patient:,
          session: create(:session),
          performed_at:,
          programme:
        )
      end

      it "returns the incoming record" do
        expect(deduplicate).to eq([first_vaccination_record])
      end

      it "discards the incoming record" do
        deduplicate
        expect(first_vaccination_record.discarded_at).not_to be_nil
      end
    end

    context "with a national reporting record" do
      before do
        Flipper.enable(:sync_national_reporting_to_imms_api)

        create(
          :vaccination_record,
          :sourced_from_national_reporting,
          patient:,
          performed_at:,
          programme:
        )
      end

      it "returns the incoming record" do
        expect(deduplicate).to eq([first_vaccination_record])
      end

      it "doesn't discard the incoming record" do
        deduplicate
        expect(first_vaccination_record.discarded_at).to be_nil
      end

      it "does not set duplicate_of_vaccination_record" do
        deduplicate
        expect(
          first_vaccination_record.duplicate_of_vaccination_record
        ).to be_nil
      end
    end

    context "with both a service record and a national reporting record" do
      let!(:service_record) do
        create(
          :vaccination_record,
          session:,
          programme:,
          patient:,
          performed_at:
        )
      end

      before do
        Flipper.enable(:sync_national_reporting_to_imms_api)

        create(
          :vaccination_record,
          :sourced_from_national_reporting,
          patient:,
          performed_at:,
          programme:
        )
      end

      it "discards the incoming record" do
        deduplicate
        expect(first_vaccination_record.discarded_at).not_to be_nil
      end

      it "points the incoming record at the service record, not the national reporting record" do
        deduplicate
        expect(first_vaccination_record.duplicate_of_vaccination_record).to eq(
          service_record
        )
      end
    end

    context "with a mix of service and nhs_immunisations_api records in the same group" do
      let(:second_vaccination_record) do
        build(
          :vaccination_record,
          :sourced_from_nhs_immunisations_api,
          programme:,
          patient:,
          nhs_immunisations_api_primary_source: false,
          performed_at:
        )
      end
      let!(:service_record) do
        create(
          :vaccination_record,
          session:,
          programme:,
          patient:,
          performed_at:
        )
      end

      it "does not discard the service record" do
        deduplicate
        expect(service_record.reload.discarded_at).to be_nil
        expect(service_record.reload.duplicate_of_vaccination_record).to be_nil
      end

      it "discards all nhs_immunisations_api records (service record exists)" do
        deduplicate
        expect(first_vaccination_record.discarded_at).not_to be_nil
        expect(second_vaccination_record.discarded_at).not_to be_nil
      end
    end

    context "with only a service record and a non-primary nhs_immunisations_api record (no primary API record)" do
      let(:first_primary_source) { false }
      let!(:service_record) do
        create(
          :vaccination_record,
          session:,
          programme:,
          patient:,
          performed_at:
        )
      end

      it "does not discard the service record" do
        deduplicate
        expect(service_record.reload.discarded_at).to be_nil
      end

      it "discards the incoming API record (because the service record exists)" do
        deduplicate
        expect(first_vaccination_record.discarded_at).not_to be_nil
      end
    end
  end

  describe "#perform" do
    subject(:perform) { described_class.new.perform(patient_id) }

    shared_examples "calls StatusUpdater" do
      it "calls StatusUpdater with the patient" do
        expect(PatientStatusUpdater).to receive(:call).with(patient:)
        perform
      end
    end

    shared_examples "sends discovery comms if required n times" do |n|
      it "calls send_vaccination_already_had_if_required n times" do
        expect(AlreadyHadNotificationSender).to receive(:call).exactly(n).times

        perform
      end
    end

    shared_examples "records the search" do
      describe "the PatientProgrammeVaccinationsSearch record" do
        it "is created or updated with the search time" do
          freeze_time

          perform

          ppis =
            PatientProgrammeVaccinationsSearch.find_by(
              patient:,
              programme_type: programme.type
            )
          expect(ppis.last_searched_at).to eq Time.current
        end
      end
    end

    shared_examples "does not record the search" do
      describe "the PatientProgrammeVaccinationsSearch record" do
        it "is not created or updated" do
          perform

          expect(
            PatientProgrammeVaccinationsSearch.find_by(
              patient:,
              programme_type: programme.type
            )
          ).to be_nil
        end
      end
    end

    let(:patient_id) { patient.id }
    let(:expected_query_immunization_target) { "3IN1,FLU,HPV,MENACWY,MMR,MMRV" }
    let(:expected_query) do
      {
        "patient.identifier" =>
          "https://fhir.nhs.uk/Id/nhs-number|#{patient.nhs_number}",
        "-immunization.target" => expected_query_immunization_target
      }
    end
    let(:status) { 200 }
    let(:body) { file_fixture("fhir/search_responses/2_results.json").read }
    let(:headers) { { "content-type" => "application/fhir+json" } }

    let(:existing_bundle) do
      FHIR.from_contents(
        file_fixture("fhir/search_responses/0_results.json").read
      )
    end
    let!(:existing_records) do
      fhir_records =
        described_class.new.send(
          :extract_fhir_vaccination_records,
          existing_bundle
        )
      mapped_records =
        fhir_records.map do |fhir_record|
          mapped =
            FHIRMapper::VaccinationRecord.from_fhir_record(
              fhir_record,
              patient:
            )
          mapped.save!

          mapped
        end

      mapped_records
    end

    before do
      stub_request(
        :get,
        "https://sandbox.api.service.nhs.uk/immunisation-fhir-api/FHIR/R4/Immunization"
      ).with(query: expected_query).to_return(status:, body:, headers:)
    end

    context "with a patient ID that doesn't exist" do
      let(:patient_id) { -1 }

      it "doesn't raise an error" do
        expect { perform }.not_to raise_error
      end
    end

    context "with 2 new incoming records" do
      it "creates new vaccination records for incoming Immunizations" do
        expect { perform }.to change { patient.vaccination_records.count }.by(2)
      end

      include_examples "sends discovery comms if required n times", 2
      include_examples "calls StatusUpdater"

      include_examples "records the search"
    end

    context "with 1 existing record and 1 new incoming record" do
      let(:existing_bundle) do
        FHIR.from_contents(
          file_fixture("fhir/search_responses/1_result.json").read
        )
      end

      it "updates existing records and creates new records not present" do
        expect { perform }.to change { patient.vaccination_records.count }.by(1)
        expect(patient.vaccination_records.map(&:id)).to include(
          existing_records.map(&:id).first
        )
        expect(existing_records.first.reload.performed_at).to eq(
          Time.parse("2025-08-22T14:16:03+01:00")
        )
      end

      include_examples "sends discovery comms if required n times", 1
      include_examples "calls StatusUpdater"
    end

    context "with 2 existing records and only 1 incoming (edited) record" do
      let(:existing_bundle) do
        FHIR.from_contents(
          file_fixture("fhir/search_responses/2_results.json").read
        )
      end
      let(:body) { file_fixture("fhir/search_responses/1_result.json").read }

      it "deletes the record that is no longer present, and edits the existing record" do
        expect { perform }.to change { patient.vaccination_records.count }.by(
          -1
        )
        expect(patient.vaccination_records.count).to eq(1)
        expect(existing_records.map(&:id)).to include(
          patient.vaccination_records.map(&:id).first
        )
        expect(patient.vaccination_records.first&.performed_at).to eq(
          Time.parse("2025-08-23T14:16:03+01:00")
        )
      end

      include_examples "sends discovery comms if required n times", 0
      include_examples "calls StatusUpdater"
    end

    context "when re-running after a previous search (patient already has API records in the DB)" do
      context "with the same 2 records returned again" do
        let(:existing_bundle) do
          FHIR.from_contents(
            file_fixture("fhir/search_responses/2_results.json").read
          )
        end

        it "does not create any new records on the second run" do
          expect { perform }.not_to(change(VaccinationRecord, :count))
        end

        it "retains the same record IDs on the second run" do
          perform # first run
          ids_after_first_run = patient.vaccination_records.map(&:id)
          perform # second run
          expect(patient.vaccination_records.reload.map(&:id)).to match_array(
            ids_after_first_run
          )
        end

        include_examples "sends discovery comms if required n times", 0
        include_examples "calls StatusUpdater"
      end

      context "with the same record returned but with updated attributes" do
        # 1_result_old_date.json and 1_result.json
        # have the same nhs_immunisations_api_id but different occurrenceDateTimes
        # (2025-08-22 vs 2025-08-23), simulating a record being corrected in the API.
        let(:existing_bundle) do
          FHIR.from_contents(
            file_fixture("fhir/search_responses/1_result_old_date.json").read
          )
        end
        let(:body) { file_fixture("fhir/search_responses/1_result.json").read }

        it "does not create a new record" do
          expect { perform }.not_to(change(VaccinationRecord, :count))
        end

        it "updates the existing record in-place" do
          expect(existing_records.first.reload.performed_at).to eq(
            Time.parse("2025-08-22T00:00:00+01:00")
          )
          perform
          expect(existing_records.first.reload.performed_at).to eq(
            Time.parse("2025-08-23T14:16:03+01:00")
          )
        end

        include_examples "sends discovery comms if required n times", 0
        include_examples "calls StatusUpdater"
      end

      context "when a Mavis service record has since been created for the same date and programme" do
        # The first run imported the API record as kept. Now a Mavis record
        # exists, so on re-run the existing API record should be updated to
        # discarded and point at the Mavis record.

        # Seed just the non-Mavis API record that the fixture will return,
        # as it would have been after the first search run.
        let(:existing_bundle) do
          FHIR.from_contents(
            file_fixture("fhir/search_responses/0_results.json").read
          )
        end
        let!(:existing_api_record) do
          create(
            :vaccination_record,
            :sourced_from_nhs_immunisations_api,
            patient:,
            programme:,
            performed_at: Time.zone.parse("2025-08-22T14:16:03+01:00"),
            nhs_immunisations_api_id: "abcdefgh-a14d-4139-bbcf-859e998d2028",
            nhs_immunisations_api_primary_source: false
          )
        end
        let(:body) do
          file_fixture(
            "fhir/search_responses/2_results_mavis_duplicate.json"
          ).read
        end
        let!(:mavis_record) do
          create(
            :vaccination_record,
            patient:,
            programme:,
            performed_at: Time.zone.parse("2025-08-22T14:16:03+01:00"),
            session:
          )
        end

        it "does not create any new API records" do
          expect { perform }.not_to(
            change do
              VaccinationRecord.sourced_from_nhs_immunisations_api.count
            end
          )
        end

        it "marks the existing API record as discarded" do
          perform
          expect(existing_api_record.reload).to be_discarded
        end

        it "points the existing API record at the Mavis record" do
          perform
          expect(
            existing_api_record.reload.duplicate_of_vaccination_record
          ).to eq(mavis_record)
        end

        include_examples "sends discovery comms if required n times", 0
        include_examples "calls StatusUpdater"
      end

      context "when a duplicate pair was previously imported and is returned again" do
        # The first run created a kept (primary) record and a discarded
        # (non-primary) record. On re-run with the same response, both should
        # be updated in-place with no new records created.
        let(:existing_bundle) do
          FHIR.from_contents(
            file_fixture("fhir/search_responses/duplicate.json").read
          )
        end
        let(:body) { file_fixture("fhir/search_responses/duplicate.json").read }

        it "does not create any new records" do
          expect { perform }.not_to(change(VaccinationRecord, :count))
        end

        it "retains the same record IDs" do
          perform
          expect(VaccinationRecord.all.map(&:id)).to match_array(
            existing_records.map(&:id)
          )
        end

        it "keeps the primary-source record as not discarded" do
          perform
          primary =
            VaccinationRecord.find_by(
              nhs_immunisations_api_primary_source: true
            )
          expect(primary).not_to be_discarded
        end

        it "keeps the non-primary-source record as discarded" do
          perform
          non_primary =
            VaccinationRecord.find_by(
              nhs_immunisations_api_primary_source: false
            )
          expect(non_primary).to be_discarded
        end

        include_examples "sends discovery comms if required n times", 0
        include_examples "calls StatusUpdater"
      end
    end

    context "with a record for each programme (total 6)" do
      shared_examples "ingests all 6 vaccination record types" do
        it "creates new vaccination records for incoming Immunizations" do
          expect { perform }.to change { patient.vaccination_records.count }.by(
            6
          )
        end

        it "creates one vaccination record of each programme" do
          perform

          programmes = patient.vaccination_records.map(&:programme)

          expect(programmes).to contain_exactly(
            Programme.flu,
            Programme.hpv,
            Programme.menacwy,
            Programme.td_ipv,
            Programme::Variant.new(Programme.mmr, variant_type: "mmr"),
            Programme::Variant.new(Programme.mmr, variant_type: "mmrv")
          )

          expect(programmes.select { |it| it.type == "mmr" }).to all(
            be_a Programme::Variant
          )
        end

        include_examples "sends discovery comms if required n times", 6
        include_examples "calls StatusUpdater"
      end

      let(:expected_query_immunization_target) do
        "3IN1,FLU,HPV,MENACWY,MMR,MMRV"
      end
      let(:body) do
        file_fixture("fhir/search_responses/all_programmes.json").read
      end

      before { Flipper.disable(:imms_api_search_job) }

      context "with all feature flags explicitly enabled" do
        before do
          Flipper.enable(:imms_api_search_job, Programme.flu)
          Flipper.enable(:imms_api_search_job, Programme.hpv)
          Flipper.enable(:imms_api_search_job, Programme.menacwy)
          Flipper.enable(:imms_api_search_job, Programme.td_ipv)
          Flipper.enable(
            :imms_api_search_job,
            Programme::Variant.new(Programme.mmr, variant_type: "mmr")
          )
          Flipper.enable(
            :imms_api_search_job,
            Programme::Variant.new(Programme.mmr, variant_type: "mmrv")
          )
        end

        it_behaves_like "ingests all 6 vaccination record types"
      end

      context "with feature flags enabled as they will be in prod" do
        before { Flipper.enable(:imms_api_search_job) }

        it_behaves_like "ingests all 6 vaccination record types"
      end
    end

    context "with a mavis record in the database" do
      let!(:service_vaccination_record) do
        create(
          :vaccination_record,
          patient:,
          programme:,
          performed_at: Time.zone.parse("2025-08-22T14:16:03+01:00"),
          session:
        )
      end

      context "with a Mavis-identifier record in the search results" do
        let(:body) do
          file_fixture("fhir/search_responses/1_result_mavis.json").read
        end

        it "does not create any API record" do
          expect { perform }.not_to(
            change do
              VaccinationRecord.sourced_from_nhs_immunisations_api.count
            end
          )
        end

        include_examples "sends discovery comms if required n times", 0
        include_examples "calls StatusUpdater"
      end

      context "with a Mavis-identifier record and a non-Mavis duplicate in the search results" do
        let(:body) do
          file_fixture(
            "fhir/search_responses/2_results_mavis_duplicate.json"
          ).read
        end

        it "creates only the non-Mavis API record, in a discarded state" do
          expect { perform }.to change {
            VaccinationRecord.sourced_from_nhs_immunisations_api.count
          }.by(1)
          expect(
            VaccinationRecord.sourced_from_nhs_immunisations_api.first
          ).to be_discarded
        end

        it "points the discarded record at the Mavis record" do
          perform
          api_record =
            VaccinationRecord.sourced_from_nhs_immunisations_api.first
          expect(api_record.duplicate_of_vaccination_record).to eq(
            service_vaccination_record
          )
        end

        include_examples "sends discovery comms if required n times", 0
        include_examples "calls StatusUpdater"
      end

      context "with a Mavis-identifier record and a non-Mavis primary source duplicate in the search results" do
        let(:body) do
          file_fixture(
            "fhir/search_responses/2_results_mavis_duplicate_primary_source.json"
          ).read
        end

        it "creates only the non-Mavis API record, in a discarded state" do
          expect { perform }.to change {
            VaccinationRecord.sourced_from_nhs_immunisations_api.count
          }.by(1)
          expect(
            VaccinationRecord.sourced_from_nhs_immunisations_api.first
          ).to be_discarded
        end

        it "points the discarded record at the Mavis record" do
          perform
          api_record =
            VaccinationRecord.sourced_from_nhs_immunisations_api.first
          expect(api_record.duplicate_of_vaccination_record).to eq(
            service_vaccination_record
          )
        end

        include_examples "sends discovery comms if required n times", 0
        include_examples "calls StatusUpdater"
      end
    end

    context "with the feature flag disabled" do
      before { Flipper.disable(:imms_api_search_job) }

      it "does not change any records locally" do
        expect { perform }.not_to(change { patient.vaccination_records.count })
      end

      include_examples "sends discovery comms if required n times", 0
    end

    context "with the per-programme feature flag disabled" do
      before do
        Flipper.disable(:imms_api_search_job)
        # Not enabled for flu, which is the incoming record's programme
        Flipper.enable(:imms_api_search_job, Programme.hpv)
      end

      it "does not change any records locally" do
        expect { perform }.not_to(change { patient.vaccination_records.count })
      end

      include_examples "sends discovery comms if required n times", 0
    end

    context "with the per-programme feature flag enabled" do
      before do
        Flipper.disable(:imms_api_search_job)
        Flipper.enable(:imms_api_search_job, Programme.flu)
      end

      it "creates new vaccination records for incoming Immunizations" do
        expect { perform }.to change { patient.vaccination_records.count }.by(2)
      end

      include_examples "sends discovery comms if required n times", 2
      include_examples "calls StatusUpdater"
    end

    context "with the :imms_api_ignore_records_prior_to_2025_academic_year flag" do
      context "when enabled for the programme" do
        before do
          Flipper.enable(
            :imms_api_ignore_records_prior_to_2025_academic_year,
            Programme.flu
          )
        end

        it "does not import pre-cutoff records" do
          expect { perform }.not_to(
            change { patient.vaccination_records.count }
          )
        end

        include_examples "sends discovery comms if required n times", 0

        context "when a record falls on the cutoff date" do
          let(:body) do
            file_fixture(
              "fhir/search_responses/1_result_in_academic_year_2025.json"
            ).read
          end

          it "imports the record" do
            expect { perform }.to change {
              patient.vaccination_records.count
            }.by(1)
          end

          include_examples "sends discovery comms if required n times", 1
          include_examples "calls StatusUpdater"
        end

        context "when pre-cutoff records were already imported" do
          let(:existing_bundle) do
            FHIR.from_contents(
              file_fixture("fhir/search_responses/2_results.json").read
            )
          end

          it "removes the pre-cutoff records on the next search run" do
            expect { perform }.to change {
              patient.vaccination_records.count
            }.by(-2)
          end

          include_examples "calls StatusUpdater"
        end
      end

      context "when enabled for a different programme" do
        before do
          Flipper.enable(
            :imms_api_ignore_records_prior_to_2025_academic_year,
            Programme.mmr
          )
        end

        it "still imports the records" do
          expect { perform }.to change { patient.vaccination_records.count }.by(
            2
          )
        end

        include_examples "sends discovery comms if required n times", 2
        include_examples "calls StatusUpdater"
      end
    end

    context "with a non-api record already on the patient" do
      let!(:vaccination_record) do
        create(:vaccination_record, patient:, programme:)
      end

      it "does not change the record which was recorded in service" do
        expect { perform }.not_to(change(vaccination_record, :reload))

        expect(patient.vaccination_records.count).to be 3
        expect(patient.vaccination_records.map(&:source)).to contain_exactly(
          "historical_upload",
          "nhs_immunisations_api",
          "nhs_immunisations_api"
        )
      end

      include_examples "sends discovery comms if required n times", 2
      include_examples "calls StatusUpdater"
      include_examples "records the search"
    end

    context "with no NHS number" do
      let(:nhs_number) { nil }

      let(:existing_bundle) do
        FHIR.from_contents(
          file_fixture("fhir/search_responses/2_results.json").read
        )
      end

      it "deletes all the API records and does not create any new ones" do
        expect { perform }.to change { patient.vaccination_records.count }.by(
          -2
        )
        expect(patient.vaccination_records.count).to eq(0)
      end

      include_examples "sends discovery comms if required n times", 0
      include_examples "calls StatusUpdater"

      include_examples "does not record the search"
    end

    context "with an existing PatientProgrammeVaccinationsSearch record" do
      before do
        create(:patient_programme_vaccinations_search, patient:, programme:)
      end

      include_examples "records the search"

      describe "the PatientProgrammeVaccinationsSearch record" do
        it "is not newly created" do
          expect { perform }.not_to(
            change do
              PatientProgrammeVaccinationsSearch.for_programme(programme).count
            end
          )
        end
      end
    end

    context "with duplicates" do
      context "with one primary and one non-primary source record" do
        let(:body) { file_fixture("fhir/search_responses/duplicate.json").read }

        it "adds both vaccination records to the database" do
          expect { perform }.to change {
            VaccinationRecord.sourced_from_nhs_immunisations_api.count
          }.by(2)
        end

        it "discards the non-primary-source record" do
          perform
          non_primary =
            VaccinationRecord.find_by(
              nhs_immunisations_api_primary_source: false
            )
          expect(non_primary).to be_discarded
        end

        it "does not discard the primary source record" do
          perform
          primary =
            VaccinationRecord.find_by(
              nhs_immunisations_api_primary_source: true
            )
          expect(primary).not_to be_discarded
        end

        it "points the non-primary-source record at the primary source record" do
          perform
          primary =
            VaccinationRecord.find_by(
              nhs_immunisations_api_primary_source: true
            )
          non_primary =
            VaccinationRecord.find_by(
              nhs_immunisations_api_primary_source: false
            )
          expect(non_primary.duplicate_of_vaccination_record).to eq(primary)
        end

        include_examples "sends discovery comms if required n times", 1
        include_examples "calls StatusUpdater"
      end
    end

    context "with a mismatching `Bundle.link`" do
      before { Flipper.enable(:imms_api_sentry_warnings) }

      let(:body) do
        file_fixture("fhir/search_responses/mismatching_bundle_link.json").read
      end

      it "raises a warning, and sends to Sentry" do
        expect(Rails.logger).to receive(:warn)
        expect(Sentry).to receive(:capture_exception).with(
          NHS::ImmunisationsAPI::BundleLinkParamsMismatch
        )

        perform
      end

      it "adds 2 vaccination records anyway" do
        expect { perform }.to change { patient.vaccination_records.count }.by(2)
      end
    end
  end
end
