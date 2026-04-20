# frozen_string_literal: true

describe BulkRemoveParentRelationshipsJob do
  include ImportsHelper
  include ActiveJob::TestHelper

  subject(:perform_job) do
    described_class.new.perform(
      import.to_global_id.to_s,
      import.parent_relationship_ids,
      user.id,
      remove_option
    )
  end

  let(:team) { create(:team) }
  let(:file) { "valid.csv" }
  let(:csv_data) { file_fixture("class_import/#{file}").read }
  let(:import) { create(:class_import, csv_data:, team:) }

  let(:user) { create(:user, team:) }

  before do
    process_and_approve_import(import)
    create(
      :consent,
      :given,
      parent: import.parent_relationships.includes(:parent).first.parent,
      patient: import.parent_relationships.includes(:patient).first.patient
    )
    create(
      :consent,
      :refused,
      parent: import.parent_relationships.includes(:parent).second.parent,
      patient: import.parent_relationships.includes(:patient).second.patient
    )
  end

  describe "#perform" do
    context "when removing only parents that havent consented" do
      let(:remove_option) { "unconsented_only" }

      it "removes only unconsented parents" do
        expect(import.parent_relationships.count).to eq(5)
        expect { perform_job }.to change {
          import.parent_relationships.count
        }.by(-3)
      end

      it "updates import status" do
        perform_job
        expect(import.reload.status).to eq("processed")
      end
    end

    context "when removing all parents" do
      let(:remove_option) { "all" }
      let(:consent_with_given_response) { Consent.response_given.sample }
      let(:consent_with_refused_response) { Consent.response_refused.sample }

      it "removes all parent relationships" do
        expect { perform_job }.to change {
          import.parent_relationships.count
        }.by(-5)
      end

      it "removes all parents that are no longer associated with a patient" do
        import_parents = import.parents.ids
        expect { perform_job }.to change {
          Parent.where(id: import_parents).count
        }.by(-3)
      end

      it "invalidates consents" do
        perform_job
        Consent.all.find_each { expect(it.reload).to be_invalidated }
      end

      it "updates import status" do
        perform_job
        expect(import.reload.status).to eq("processed")
      end

      context "when consents have associated vaccination records" do
        let!(:vaccination_record) do
          create(
            :vaccination_record,
            :administered,
            patient: consent_with_given_response.patient,
            programme: consent_with_given_response.programme,
            notify_parents: true
          )
        end

        it "updates vaccination records' notify_parents flag" do
          expect { perform_job }.to(
            change { vaccination_record.reload.notify_parents }
          )
        end
      end

      context "when consents have associated triages" do
        let!(:triage) do
          create(
            :triage,
            :safe_to_vaccinate,
            patient: consent_with_given_response.patient,
            programme_type: consent_with_given_response.programme_type,
            academic_year: consent_with_given_response.academic_year
          )
        end

        it "invalidates triages for the consent's patient/programme/academic year" do
          expect(triage).not_to be_invalidated
          perform_job
          expect(triage.reload).to be_invalidated
        end

        it "does not invalidate triages for different academic years" do
          different_year_triage =
            create(
              :triage,
              :safe_to_vaccinate,
              patient: consent_with_given_response.patient,
              programme_type: consent_with_given_response.programme_type,
              academic_year: consent_with_given_response.academic_year - 1
            )

          perform_job
          expect(different_year_triage.reload).not_to be_invalidated
        end

        it "does not invalidate triages for different programme types" do
          different_programme_type =
            (
              Programme.all.map(&:type) -
                [consent_with_given_response.programme_type]
            ).sample
          different_programme_triage =
            create(
              :triage,
              :safe_to_vaccinate,
              patient: consent_with_given_response.patient,
              programme_type: different_programme_type,
              academic_year: consent_with_given_response.academic_year
            )

          perform_job
          expect(different_programme_triage.reload).not_to be_invalidated
        end
      end

      context "when consents have associated patient specific directions" do
        let!(:patient_specific_direction) do
          create(
            :patient_specific_direction,
            patient: consent_with_given_response.patient,
            programme_type: consent_with_given_response.programme_type,
            academic_year: consent_with_given_response.academic_year
          )
        end

        it "invalidates patient specific directions for the consent's patient/programme/academic year" do
          expect(patient_specific_direction).not_to be_invalidated
          perform_job
          expect(patient_specific_direction.reload).to be_invalidated
        end

        it "does not invalidate patient specific directions for different academic years" do
          different_year_psd =
            create(
              :patient_specific_direction,
              patient: consent_with_given_response.patient,
              programme_type: consent_with_given_response.programme_type,
              academic_year: consent_with_given_response.academic_year + 1
            )

          perform_job
          expect(different_year_psd.reload).not_to be_invalidated
        end

        it "does not invalidate patient specific directions for different programme types" do
          different_programme_type =
            (
              Programme.all.map(&:type) -
                [consent_with_given_response.programme_type]
            ).sample
          different_programme_psd =
            create(
              :patient_specific_direction,
              patient: consent_with_given_response.patient,
              programme_type: different_programme_type,
              academic_year: consent_with_given_response.academic_year
            )

          perform_job
          expect(different_programme_psd.reload).not_to be_invalidated
        end
      end
    end
  end
end
