# frozen_string_literal: true

describe ProcessPatientChangesetJob, :pds do
  include ActiveJob::TestHelper

  let(:programme) { Programme.hpv }
  let(:team) { create(:team, programmes: [programme]) }
  let(:import) { create(:cohort_import, team:) }

  let(:patient_changeset) do
    create(
      :patient_changeset,
      import: import,
      status: :pending,
      data: {
        upload: {
          child: {
            given_name: "Betty",
            family_name: "Samson",
            date_of_birth: "2010-01-01",
            address_postcode: "SW1A 1AA"
          }
        },
        search_results:
      }
    )
  end

  let(:search_results) { [] }

  describe "#perform" do
    context "when changeset is already processed" do
      before { patient_changeset.processed! }

      it "does nothing" do
        expect { described_class.perform_now(patient_changeset.id) }.not_to(
          change { patient_changeset.reload.updated_at }
        )
      end

      it "does not enqueue ReviewPatientChangesetJob" do
        expect {
          described_class.perform_now(patient_changeset.id)
        }.not_to enqueue_sidekiq_job(ReviewPatientChangesetJob)
      end
    end

    context "when one unique NHS number found" do
      let(:search_results) do
        [
          {
            "step" => "no_fuzzy_with_history",
            "result" => "one_match",
            "nhs_number" => "9449306168",
            "created_at" => Time.current.iso8601(3)
          },
          {
            "step" => "no_fuzzy_with_wildcard_postcode",
            "result" => "one_match",
            "nhs_number" => "9449306168",
            "created_at" => Time.current.iso8601(3)
          }
        ]
      end

      it "saves the NHS number to child_attributes" do
        described_class.perform_now(patient_changeset.id)

        expect(patient_changeset.reload.child_attributes["nhs_number"]).to eq(
          "9449306168"
        )
      end

      it "saves the NHS number to pds_nhs_number" do
        described_class.perform_now(patient_changeset.id)

        expect(patient_changeset.reload.pds_nhs_number).to eq("9449306168")
      end

      it "marks changeset as calculating_review" do
        described_class.perform_now(patient_changeset.id)

        expect(patient_changeset.reload).to be_calculating_review
      end
    end

    context "when conflicting NHS numbers found" do
      let(:search_results) do
        [
          {
            "step" => "no_fuzzy_with_history",
            "result" => "one_match",
            "nhs_number" => "9449306168",
            "created_at" => Time.current.iso8601(3)
          },
          {
            "step" => "no_fuzzy_with_wildcard_postcode",
            "result" => "one_match",
            "nhs_number" => "9876543210",
            "created_at" => Time.current.iso8601(3)
          }
        ]
      end

      it "does not save any NHS number" do
        described_class.perform_now(patient_changeset.id)

        expect(
          patient_changeset.reload.child_attributes["nhs_number"]
        ).to be_nil
        expect(patient_changeset.reload.pds_nhs_number).to be_nil
      end

      it "marks changeset as calculating_review" do
        described_class.perform_now(patient_changeset.id)

        expect(patient_changeset.reload).to be_calculating_review
      end
    end

    context "when no NHS numbers found" do
      let(:search_results) do
        [
          {
            "step" => "no_fuzzy_with_history",
            "result" => "no_matches",
            "nhs_number" => nil,
            "created_at" => Time.current.iso8601(3)
          },
          {
            "step" => "no_fuzzy_with_wildcard_postcode",
            "result" => "no_matches",
            "nhs_number" => nil,
            "created_at" => Time.current.iso8601(3)
          }
        ]
      end

      it "does not save any NHS number" do
        described_class.perform_now(patient_changeset.id)

        expect(
          patient_changeset.reload.child_attributes["nhs_number"]
        ).to be_nil
        expect(patient_changeset.reload.pds_nhs_number).to be_nil
      end

      it "marks changeset as calculating_review" do
        described_class.perform_now(patient_changeset.id)

        expect(patient_changeset.reload).to be_calculating_review
      end
    end

    context "when all changesets are processed" do
      let(:search_results) do
        [
          {
            "step" => "no_fuzzy_with_history",
            "result" => "one_match",
            "nhs_number" => "9449306168",
            "created_at" => Time.current.iso8601(3)
          }
        ]
      end

      context "when <70% pds match rate" do
        before do
          create_list(
            :patient_changeset,
            6,
            :with_pds_match,
            import:,
            status: :processed
          )
          create_list(:patient_changeset, 4, import:, status: :processed)
        end

        context "when pds_search_during_import flag is disabled" do
          it "doesn't change import status" do
            described_class.perform_now(patient_changeset.id)
            expect(import.reload.status).to eq("pending_import")
          end
        end

        context "when pds_search_during_import flag is enabled" do
          before { Flipper.enable(:pds_search_during_import) }

          it "marks import as low_pds_match_rate and stops" do
            described_class.perform_now(patient_changeset.id)
            expect(import.reload.status).to eq("low_pds_match_rate")
          end

          it "updates changesets to import_invalid and stops" do
            described_class.perform_now(patient_changeset.id)
            expect(import.changesets.pluck(:status).uniq).to eq(
              ["import_invalid"]
            )
          end

          it "doesn't enqueue ReviewPatientChangesetJob" do
            expect {
              described_class.perform_now(patient_changeset.id)
            }.not_to enqueue_sidekiq_job(ReviewPatientChangesetJob)
          end
        end
      end

      context "when >70% pds match rate" do
        let(:changeset_a) do
          create(
            :patient_changeset,
            :with_pds_match,
            import:,
            status: :processed
          )
        end
        let(:changeset_b) do
          create(
            :patient_changeset,
            :with_pds_match,
            import:,
            status: :processed
          )
        end
        let(:patient_a) { create(:patient) }
        let(:patient_b) { create(:patient) }

        before do
          create_list(
            :patient_changeset,
            7,
            :with_pds_match,
            import:,
            status: :processed
          )
          create_list(:patient_changeset, 1, import:, status: :processed)
        end

        context "when changesets have unique NHS numbers and unique patients" do
          it "enqueues ReviewPatientChangesetJob" do
            expect {
              described_class.new.perform(patient_changeset.id)
            }.to enqueue_sidekiq_job(ReviewPatientChangesetJob).with(
              patient_changeset.id
            )
          end
        end

        context "when changesets share NHS number but different patients" do
          before do
            changeset_a.update!(
              data: {
                upload: {
                  child: {
                    nhs_number: "1111111111"
                  }
                }
              }
            )
            changeset_a.update!(patient_id: patient_a.id)
            changeset_b.update!(
              data: {
                upload: {
                  child: {
                    nhs_number: "1111111111"
                  }
                }
              }
            )
            changeset_b.update!(patient_id: patient_b.id)
          end

          it "marks import as changesets_are_invalid" do
            described_class.perform_now(patient_changeset.id)
            expect(import.reload.status).to eq("changesets_are_invalid")
          end

          it "adds duplicate NHS number error to import" do
            described_class.perform_now(patient_changeset.id)
            expect(import.reload.serialized_errors.values.flatten).to include(
              /The details on this row match row \d+\. Mavis has found the NHS number 1111111111\./
            )
          end

          it "updates the status of changesets to import_invalid" do
            described_class.perform_now(patient_changeset.id)
            expect(import.changesets.pluck(:status).uniq).to eq(
              ["import_invalid"]
            )
          end
        end

        context "when changesets share patient but different NHS numbers" do
          before do
            changeset_a.update!(
              data: {
                upload: {
                  child: {
                    nhs_number: "1111111111"
                  }
                }
              }
            )
            changeset_a.update!(patient_id: patient_a.id)
            changeset_b.update!(
              data: {
                upload: {
                  child: {
                    nhs_number: "2222222222"
                  }
                }
              }
            )
            changeset_b.update!(patient_id: patient_a.id)
          end

          it "marks import as changesets_are_invalid" do
            described_class.perform_now(patient_changeset.id)
            expect(import.reload.status).to eq("changesets_are_invalid")
          end

          it "adds duplicate patient error to import" do
            described_class.perform_now(patient_changeset.id)
            import.load_serialized_errors!
            expect(import.reload.serialized_errors.values.flatten).to include(
              /The record on this row appears to be a duplicate of row \d+./
            )
          end

          it "updates the status of changesets to import_invalid" do
            described_class.perform_now(patient_changeset.id)
            expect(import.changesets.pluck(:status).uniq).to eq(
              ["import_invalid"]
            )
          end
        end

        context "when changesets share both patient and NHS number" do
          before do
            changeset_a.update!(
              data: {
                upload: {
                  child: {
                    nhs_number: "1111111111"
                  }
                }
              }
            )
            changeset_a.update!(patient_id: patient_a.id)
            changeset_b.update!(
              data: {
                upload: {
                  child: {
                    nhs_number: "1111111111"
                  }
                }
              }
            )
            changeset_b.update!(patient_id: patient_a.id)
          end

          it "marks import as changesets_are_invalid" do
            described_class.perform_now(patient_changeset.id)
            expect(import.reload.status).to eq("changesets_are_invalid")
          end

          it "adds both duplicate NHS number and duplicate patient errors to import" do
            described_class.perform_now(patient_changeset.id)
            import.load_serialized_errors!
            expect(import.reload.serialized_errors.values.flatten).to include(
              /The details on this row match row \d+\. Mavis has found the NHS number 1111111111\./,
              /The record on this row appears to be a duplicate of row \d+\./
            )
          end

          it "updates the status of changesets to import_invalid" do
            described_class.perform_now(patient_changeset.id)
            expect(import.changesets.pluck(:status).uniq).to eq(
              ["import_invalid"]
            )
          end
        end
      end
    end

    context "when some changesets are processed and some pending" do
      let(:search_results) do
        [
          {
            "step" => "no_fuzzy_with_history",
            "result" => "one_match",
            "nhs_number" => "9449306168",
            "created_at" => Time.current.iso8601(3)
          }
        ]
      end

      before do
        create(:patient_changeset, import:, status: :processed)
        create(:patient_changeset, import:, status: :pending)
      end

      it "enqueues ReviewPatientChangesetJob" do
        expect {
          described_class.perform_now(patient_changeset.id)
        }.to enqueue_sidekiq_job(ReviewPatientChangesetJob).with(
          patient_changeset.id
        )
      end

      it "does not validate PDS match rate or uniqueness" do
        expect(import).not_to receive(:validate_pds_match_rate!)
        expect(import).not_to receive(:validate_changeset_uniqueness!)
        described_class.perform_now(patient_changeset.id)
      end
    end

    context "when passed a PatientChangeset object" do
      let(:search_results) do
        [
          {
            "step" => "no_fuzzy_with_history",
            "result" => "one_match",
            "nhs_number" => "9449306168",
            "created_at" => Time.current.iso8601(3)
          }
        ]
      end

      it "processes the changeset correctly" do
        described_class.perform_now(patient_changeset.id)

        expect(patient_changeset.reload).to be_calculating_review
        expect(patient_changeset.child_attributes["nhs_number"]).to eq(
          "9449306168"
        )
      end
    end
  end
end
