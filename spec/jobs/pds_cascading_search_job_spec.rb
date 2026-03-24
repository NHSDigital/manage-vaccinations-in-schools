# frozen_string_literal: true

describe PDSCascadingSearchJob do
  include ActiveJob::TestHelper
  include ImportsHelper

  let(:today) { Time.zone.local(2025, 9, 1, 12, 0, 0) }
  let(:programme) { Programme.hpv }
  let(:school) { create(:gias_school, urn: "123456", team:) }
  let(:team) { create(:team, programmes: [programme]) }
  let(:session) do
    create(:session, team:, location: school, programmes: [programme])
  end
  let(:import) { create(:cohort_import, team:) }
  let(:mock_patient) { instance_double(PDS::Patient, nhs_number: "9449306168") }

  let(:patient_changeset) do
    create(
      :patient_changeset,
      import: import,
      data: {
        upload: {
          child: {
            given_name: "Betty",
            family_name: "Samson",
            date_of_birth: "2010-01-01",
            address_postcode: "SW1A 1AA"
          }
        },
        search_results: []
      }
    )
  end

  around { |example| travel_to(today) { example.run } }

  describe "#perform" do
    context "when finding a patient on first attempt" do
      before do
        allow(PDS::Patient).to receive(:search).and_return(mock_patient)
      end

      it "saves the search result and enqueues ProcessPatientChangesetJob" do
        expect {
          described_class.perform_now(patient_changeset)
        }.to have_enqueued_job(ProcessPatientChangesetJob).with(
          patient_changeset.id
        )

        patient_changeset.reload

        expect(patient_changeset.search_results.count).to eq(1)
        expect(patient_changeset.search_results.first).to include(
          "step" => "no_fuzzy_with_history",
          "result" => "one_match",
          "nhs_number" => "9449306168"
        )
      end
    end

    context "when no match found, cascading through steps" do
      before { allow(PDS::Patient).to receive(:search).and_return(nil) }

      it "enqueues next search step on no match" do
        expect {
          described_class.perform_now(
            patient_changeset,
            step_name: :no_fuzzy_with_history
          )
        }.to have_enqueued_job(described_class).with(
          patient_changeset,
          step_name: :no_fuzzy_with_wildcard_postcode,
          search_results: [
            {
              "step" => :no_fuzzy_with_history,
              "result" => :no_matches,
              "nhs_number" => nil,
              "created_at" => Time.current
            }
          ],
          queue: :pds
        )
      end
    end

    context "when no postcode provided" do
      let(:patient_changeset) do
        create(
          :patient_changeset,
          import: import,
          data: {
            upload: {
              child: {
                given_name: "Charlie",
                family_name: "Brown",
                date_of_birth: "2010-01-01",
                address_postcode: nil
              }
            },
            search_results: []
          }
        )
      end

      it "records no_postcode result and enqueues ProcessPatientChangesetJob" do
        expect {
          described_class.perform_now(patient_changeset)
        }.to have_enqueued_job(ProcessPatientChangesetJob).with(
          patient_changeset.id
        )

        patient_changeset.reload

        expect(patient_changeset.search_results.first).to include(
          "step" => "no_fuzzy_with_history",
          "result" => "no_postcode"
        )
      end
    end

    context "when name too short for wildcard search" do
      let(:patient_changeset) do
        create(
          :patient_changeset,
          import: import,
          data: {
            upload: {
              child: {
                given_name: "Ed",
                family_name: "Li",
                date_of_birth: "2010-01-01",
                address_postcode: "SW1A 1AA"
              }
            },
            search_results: []
          }
        )
      end

      before { allow(PDS::Patient).to receive(:search).and_return(nil) }

      it "skips wildcard name steps and completes search" do
        described_class.perform_now(patient_changeset)

        perform_enqueued_jobs_while_exists(only: described_class)
        perform_enqueued_jobs(only: ProcessPatientChangesetJob)

        patient_changeset.reload

        skip_results =
          patient_changeset.search_results.select do |r|
            r["result"] == "skip_step"
          end
        expect(skip_results.count).to eq(2)
        expect(skip_results.map { |r| r["step"] }).to contain_exactly(
          "no_fuzzy_with_wildcard_given_name",
          "no_fuzzy_with_wildcard_family_name"
        )
      end
    end

    context "when multiple NHS numbers found across steps" do
      it "stops cascading and enqueues ProcessPatientChangesetJob" do
        allow(PDS::Patient).to receive(:search).and_return(mock_patient)

        described_class.perform_now(
          patient_changeset,
          step_name: :no_fuzzy_with_history
        )

        patient_changeset.reload
        patient_changeset.search_results << {
          step: "no_fuzzy_with_wildcard_postcode",
          result: "one_match",
          nhs_number: "9876543210",
          created_at: Time.current
        }.with_indifferent_access
        patient_changeset.save!

        expect {
          described_class.perform_now(
            patient_changeset,
            step_name: :no_fuzzy_with_wildcard_given_name,
            search_results: patient_changeset.search_results
          )
        }.to have_enqueued_job(ProcessPatientChangesetJob).with(
          patient_changeset.id
        )
      end
    end

    context "when PDS API returns error" do
      before do
        allow(PDS::Patient).to receive(:search).and_raise(
          Faraday::ServerError.new("error", status: 500)
        )
      end

      it "records error result and enqueues ProcessPatientChangesetJob" do
        expect(Sentry).to receive(:capture_exception)

        expect {
          described_class.perform_now(patient_changeset)
        }.to have_enqueued_job(ProcessPatientChangesetJob).with(
          patient_changeset.id
        )

        patient_changeset.reload

        expect(patient_changeset.search_results.first).to include(
          "step" => "no_fuzzy_with_history",
          "result" => "error"
        )
      end
    end

    context "when PDS API returns an invalid search data error" do
      before do
        allow(PDS::Patient).to receive(:search).and_raise(
          NHS::PDS::InvalidSearchData.new
        )
      end

      it "records error result and enqueues ProcessPatientChangesetJob" do
        expect(Sentry).to receive(:capture_exception)

        expect {
          described_class.perform_now(patient_changeset)
        }.to have_enqueued_job(ProcessPatientChangesetJob).with(
          patient_changeset.id
        )

        patient_changeset.reload

        expect(patient_changeset.search_results.first).to include(
          "step" => "no_fuzzy_with_history",
          "result" => "error"
        )
      end
    end

    context "when too many matches found on first step" do
      before do
        allow(PDS::Patient).to receive(:search).and_raise(
          NHS::PDS::TooManyMatches
        )
      end

      it "enqueues next step (no_fuzzy_without_history)" do
        expect {
          described_class.perform_now(patient_changeset)
        }.to have_enqueued_job(described_class).with(
          patient_changeset,
          step_name: :no_fuzzy_without_history,
          search_results: [
            {
              "step" => :no_fuzzy_with_history,
              "result" => :too_many_matches,
              "nhs_number" => nil,
              "created_at" => Time.current
            }.with_indifferent_access
          ],
          queue: :pds
        )
      end
    end

    context "when reaching give_up step" do
      before do
        allow(PDS::Patient).to receive(:search).and_raise(
          NHS::PDS::TooManyMatches
        )
      end

      it "stops cascading and enqueues ProcessPatientChangesetJob" do
        described_class.perform_now(
          patient_changeset,
          step_name: :no_fuzzy_with_history
        )

        expect {
          described_class.perform_now(
            patient_changeset,
            step_name: :no_fuzzy_without_history
          )
        }.to have_enqueued_job(ProcessPatientChangesetJob).with(
          patient_changeset.id
        )
      end
    end

    context "when running for a Patient object" do
      let(:patient) { create(:patient, nhs_number: nil) }

      let(:search_results) { [] }

      before do
        allow(PDS::Patient).to receive(:search).and_return(mock_patient)
      end

      it "saves the search result into the provided array and enqueues PatientUpdateFromPDSJob" do
        expect {
          described_class.perform_now(patient, search_results:)
        }.to have_enqueued_job(PatientUpdateFromPDSJob).with(
          patient,
          search_results
        )

        expect(search_results.count).to eq(1)
        expect(search_results.first).to include(
          step: :no_fuzzy_with_history,
          result: :one_match,
          nhs_number: "9449306168"
        )
      end

      it "enqueues next step when no matches found" do
        allow(PDS::Patient).to receive(:search).and_return(nil)

        expect {
          described_class.perform_now(
            patient,
            step_name: :no_fuzzy_with_history,
            search_results: search_results
          )
        }.to have_enqueued_job(described_class).with(
          patient,
          step_name: :no_fuzzy_with_wildcard_postcode,
          search_results: search_results,
          queue: :pds
        )
      end

      it "stops cascading when multiple NHS numbers found" do
        search_results.concat(
          [
            {
              step: "no_fuzzy_with_history",
              result: "one_match",
              nhs_number: "9435780156",
              created_at: Time.current
            }.with_indifferent_access,
            {
              step: "no_fuzzy_with_history",
              result: "one_match",
              nhs_number: "9435792103",
              created_at: Time.current
            }.with_indifferent_access
          ]
        )

        expect {
          described_class.perform_now(patient, search_results:)
        }.to have_enqueued_job(PatientUpdateFromPDSJob).with(
          patient,
          search_results
        )
      end

      it "records error result and enqueues PatientUpdateFromPDSJob on PDS error" do
        allow(PDS::Patient).to receive(:search).and_raise(
          Faraday::ServerError.new("boom", status: 500)
        )

        expect(Sentry).to receive(:capture_exception)

        expect {
          described_class.perform_now(patient, search_results:)
        }.to have_enqueued_job(PatientUpdateFromPDSJob).with(
          patient,
          search_results
        )

        expect(search_results.first).to include(result: :error)
      end
    end
  end
end
