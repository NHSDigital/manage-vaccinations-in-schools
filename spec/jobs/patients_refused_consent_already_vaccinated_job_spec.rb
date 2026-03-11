# frozen_string_literal: true

describe PatientsRefusedConsentAlreadyVaccinatedJob do
  subject(:perform_now) do
    PatientStatusUpdater.call
    described_class.perform_now
  end

  around { |example| travel_to(today) { example.run } }

  let(:programmes) { [Programme.flu] }
  let(:session) { create(:session, programmes:) }

  context "during the preparation period" do
    let(:today) { Date.new(2025, 8, 1) }

    context "with a vaccinated patient" do
      before { create(:patient, :vaccinated, session:, year_group: 7) }

      it "does not create a vaccination record" do
        expect { perform_now }.not_to change(VaccinationRecord, :count)
      end
    end

    context "with an unvaccinated patient and no consent" do
      before { create(:patient, session:, year_group: 7) }

      it "does not create a vaccination record" do
        expect { perform_now }.not_to change(VaccinationRecord, :count)
      end
    end

    context "with an unvaccinated patient and consent given" do
      before do
        create(
          :patient,
          :consent_given_triage_not_needed,
          session:,
          year_group: 7
        )
      end

      it "does not create a vaccination record" do
        expect { perform_now }.not_to change(VaccinationRecord, :count)
      end
    end

    context "with an unvaccinated patient and consent refused" do
      let(:patient) do
        create(:patient, :consent_refused, session:, year_group: 7)
      end

      let(:consent) { patient.consents.first }

      context "when refused for personal reasons" do
        before { consent.update!(reason_for_refusal: "personal_choice") }

        it "does not create a vaccination record" do
          expect { perform_now }.not_to change(VaccinationRecord, :count)
        end
      end

      context "when refused because already vaccinated" do
        before { consent.update!(reason_for_refusal: "already_vaccinated") }

        it "creates a vaccination record" do
          expect { perform_now }.to change(VaccinationRecord, :count)

          vaccination_record = VaccinationRecord.last
          expect(vaccination_record).to be_already_had
          expect(vaccination_record.location_name).to eq("Unknown")
          expect(vaccination_record.notes).to eq(
            "Self-reported by #{consent.name} (mum)"
          )
          expect(vaccination_record.patient).to eq(patient)
          expect(vaccination_record.performed_at).to eq(consent.submitted_at)
          expect(vaccination_record.programme).to eq(programmes.first)
        end
      end
    end
  end

  context "outside the preparation period" do
    let(:today) { Date.new(2025, 7, 31) }

    context "with a vaccinated patient" do
      before { create(:patient, :vaccinated, session:, year_group: 7) }

      it "does not create a vaccination record" do
        expect { perform_now }.not_to change(VaccinationRecord, :count)
      end
    end

    context "with an unvaccinated patient and no consent" do
      before { create(:patient, session:, year_group: 7) }

      it "does not create a vaccination record" do
        expect { perform_now }.not_to change(VaccinationRecord, :count)
      end
    end

    context "with an unvaccinated patient and consent given" do
      before do
        create(
          :patient,
          :consent_given_triage_not_needed,
          session:,
          year_group: 7
        )
      end

      it "does not create a vaccination record" do
        expect { perform_now }.not_to change(VaccinationRecord, :count)
      end
    end

    context "with an unvaccinated patient and consent refused" do
      let(:patient) do
        create(:patient, :consent_refused, session:, year_group: 7)
      end

      let(:consent) { patient.consents.first }

      context "when refused for personal reasons" do
        before { consent.update!(reason_for_refusal: "personal_choice") }

        it "does not create a vaccination record" do
          expect { perform_now }.not_to change(VaccinationRecord, :count)
        end
      end

      context "when refused because already vaccinated" do
        before { consent.update!(reason_for_refusal: "already_vaccinated") }

        it "does not create a vaccination record" do
          expect { perform_now }.not_to change(VaccinationRecord, :count)
        end
      end
    end
  end
end
