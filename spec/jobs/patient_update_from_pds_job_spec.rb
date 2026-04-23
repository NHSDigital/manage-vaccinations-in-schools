# frozen_string_literal: true

describe PatientUpdateFromPDSJob do
  include PDSHelper

  subject(:perform_now) { described_class.perform_now(patient) }

  context "when main switch is disabled" do
    let!(:patient) { create(:patient, nhs_number: "9000000009") }

    it "makes no requests to PDS" do
      expect(patient).not_to receive(:update_from_pds!)
      # WebMock will raise an error if the request is made
      perform_now
    end
  end

  context "when main switch is enabled" do
    before { Flipper.enable(:pds) }

    context "without an NHS number" do
      let(:patient) { create(:patient, nhs_number: nil) }

      it "raises an error" do
        expect { perform_now }.to raise_error(
          PatientUpdateFromPDSJob::MissingNHSNumber
        )
      end
    end

    context "with an NHS number" do
      before { create(:gp_practice, ods_code: "Y12345") }

      context "when the patient is valid" do
        before do
          stub_request(
            :get,
            Addressable::Template.new(
              "https://sandbox.api.service.nhs.uk/personal-demographics/FHIR/R4/Patient/{nhs_number}"
            )
          ).to_return(
            body: file_fixture("pds/get-patient-response.json"),
            headers: {
              "Content-Type" => "application/fhir+json"
            }
          )
        end

        let!(:patient) { create(:patient, nhs_number: "9000000009") }

        it "updates the patient details from PDS" do
          expect(patient).to receive(:update_from_pds!)
          perform_now
        end

        it "doesn't change the NHS number" do
          expect { perform_now }.not_to change(patient, :nhs_number)
        end

        it "doesn't delete the patient number" do
          expect { perform_now }.not_to change(Patient, :count)
        end

        it "doesn't queue a job to look up NHS number" do
          expect { perform_now }.not_to have_enqueued_job(PDSCascadingSearchJob)
        end

        context "when the patient is invalidated" do
          let!(:patient) do
            create(:patient, :invalidated, nhs_number: "9000000009")
          end

          it "updates the patient details from PDS" do
            expect(patient).to receive(:update_from_pds!)
            perform_now
          end
        end

        context "when the NHS number for the patient has changed" do
          let!(:patient) { create(:patient, nhs_number: "0123456789") }

          it "updates the NHS number" do
            expect { perform_now }.to change(patient, :nhs_number).to(
              "9000000009"
            )
          end

          context "when a patient already exists for the new NHS number" do
            before { create(:patient, nhs_number: "9000000009") }

            it "deletes the patient without an NHS number" do
              expect { perform_now }.to change(Patient, :count).by(-1)
              expect { patient.reload }.to raise_error(
                ActiveRecord::RecordNotFound
              )
            end
          end
        end
      end

      context "when the patient is invalid" do
        before do
          stub_request(
            :get,
            "https://sandbox.api.service.nhs.uk/personal-demographics/FHIR/R4/Patient/9000000009"
          ).to_return(
            body: file_fixture("pds/invalid-patient-response.json"),
            status: 404,
            headers: {
              "Content-Type" => "application/fhir+json"
            }
          )
        end

        let(:patient) { create(:patient, nhs_number: "9000000009") }

        it "marks the patient as invalid" do
          expect(patient).to receive(:invalidate!)
          perform_now
        end

        it "queues a job to look up NHS number using PDS cascading search" do
          expect { perform_now }.to have_enqueued_job(
            PDSCascadingSearchJob
          ).with(patient)
        end
      end

      context "when the NHS number is invalid" do
        before do
          stub_request(
            :get,
            "https://sandbox.api.service.nhs.uk/personal-demographics/FHIR/R4/Patient/9000000009"
          ).to_return(
            body: file_fixture("pds/invalid-nhs-number-response.json"),
            status: 400,
            headers: {
              "Content-Type" => "application/fhir+json"
            }
          )
        end

        let(:patient) { create(:patient, nhs_number: "9000000009") }

        it "marks the patient as invalid" do
          expect(patient).to receive(:invalidate!)
          perform_now
        end

        it "doesn't remove the NHS number" do
          expect { perform_now }.not_to change(patient, :nhs_number)
        end

        it "queues a job to look up NHS number using PDS cascading search" do
          expect { perform_now }.to have_enqueued_job(
            PDSCascadingSearchJob
          ).with(patient)
        end
      end

      context "when the NHS number is not found" do
        before do
          stub_request(
            :get,
            "https://sandbox.api.service.nhs.uk/personal-demographics/FHIR/R4/Patient/9000000009"
          ).to_return(
            body: file_fixture("pds/not-found-patient-response.json"),
            status: 404,
            headers: {
              "Content-Type" => "application/fhir+json"
            }
          )
        end

        let(:patient) { create(:patient, nhs_number: "9000000009") }

        it "doesn't mark the patient as invalid" do
          expect(patient).not_to receive(:invalidate!)
          perform_now
        end

        it "removes the NHS number" do
          expect { perform_now }.to change(patient, :nhs_number).to(nil)
        end

        it "queues a job to look up NHS number using PDS cascading search" do
          expect { perform_now }.to have_enqueued_job(
            PDSCascadingSearchJob
          ).with(patient)
        end
      end
    end

    context "when search_results are provided" do
      let!(:patient) { create(:patient, nhs_number: nil) }

      let(:search_results) do
        [
          {
            step: "no_fuzzy_with_wildcard_family_name",
            result: "one_match",
            nhs_number: "9000000009",
            created_at: Time.zone.now
          }.with_indifferent_access,
          {
            step: "no_fuzzy_with_wildcard_given_name",
            result: "one_match",
            nhs_number: "9000000009",
            created_at: 1.minute.ago
          }.with_indifferent_access
        ]
      end

      before { stub_pds_get_nhs_number_to_return_a_patient("9000000009") }

      it "imports the search results for the patient" do
        expect {
          described_class.perform_now(patient, search_results)
        }.to change(PDSSearchResult, :count).by(2)

        created_results = PDSSearchResult.where(patient_id: patient.id)
        expect(created_results.pluck(:step)).to match_array(
          %w[
            no_fuzzy_with_wildcard_family_name
            no_fuzzy_with_wildcard_given_name
          ]
        )
        expect(created_results.pluck(:nhs_number)).to all(eq("9000000009"))
      end

      it "does not raise an error when NHS number is nil but search_results are present" do
        expect {
          described_class.perform_now(patient, search_results)
        }.not_to raise_error
      end

      context "with conflicting NHS numbers in search results" do
        let(:search_results) do
          [
            {
              step: "no_fuzzy_with_wildcard_family_name",
              result: "one_match",
              nhs_number: "9000000009",
              created_at: Time.zone.now
            }.with_indifferent_access,
            {
              step: "no_fuzzy_with_wildcard_given_name",
              result: "one_match",
              nhs_number: "9000000018",
              created_at: 1.minute.ago
            }.with_indifferent_access
          ]
        end

        it "doesn't update the patient" do
          expect(patient).not_to receive(:update_from_pds!)
          described_class.perform_now(patient, search_results)
        end
      end
    end
  end
end
