# frozen_string_literal: true

describe InvalidateSelfConsentsJob do
  subject(:perform) { described_class.new.perform }

  let(:academic_year) { AcademicYear.current }
  let(:programme) { Programme.hpv }
  let(:patient) { consent.patient }
  let(:team) { consent.team }

  context "with parental consent from yesterday" do
    let(:consent) do
      create(:consent, programme:, academic_year:, created_at: 1.day.ago)
    end

    before { create(:patient_programme_status, :due, patient:, programme:) }

    it "does not invalidate the consent" do
      expect { perform }.not_to(change { consent.reload.invalidated? })
    end

    context "with triage" do
      let(:triage) do
        create(
          :triage,
          :safe_to_vaccinate,
          academic_year:,
          created_at: 1.day.ago,
          team:,
          programme:,
          patient:
        )
      end

      it "does not invalidate the triage" do
        expect { perform }.not_to(change { triage.reload.invalidated? })
      end
    end
  end

  context "with parental consent from today" do
    let(:consent) { create(:consent, programme:, academic_year:) }

    before { create(:patient_programme_status, :due, patient:, programme:) }

    it "does not invalidate the consent" do
      expect { perform }.not_to(change { consent.reload.invalidated? })
    end

    context "with triage" do
      let(:triage) do
        create(
          :triage,
          :safe_to_vaccinate,
          academic_year:,
          team:,
          programme:,
          patient:
        )
      end

      it "does not invalidate the triage" do
        expect { perform }.not_to(change { triage.reload.invalidated? })
      end
    end
  end

  context "with self-consent from yesterday" do
    let(:consent) do
      create(
        :consent,
        :self_consent,
        programme:,
        academic_year:,
        created_at: 1.day.ago
      )
    end

    before { create(:patient_programme_status, :due, patient:, programme:) }

    it "invalidates the consent" do
      expect { perform }.to change { consent.reload.invalidated? }.from(
        false
      ).to(true)
    end

    context "with triage" do
      let(:triage) do
        create(
          :triage,
          :safe_to_vaccinate,
          academic_year:,
          created_at: 1.day.ago,
          team:,
          programme:,
          patient:
        )
      end

      it "invalidates the triage" do
        expect { perform }.to change { triage.reload.invalidated? }.from(
          false
        ).to(true)
      end
    end

    context "with an expired delay vaccination triage" do
      let(:triage) do
        create(
          :triage,
          :delay_vaccination,
          academic_year:,
          created_at: 1.day.ago,
          delay_vaccination_until: 1.day.ago,
          team:,
          programme:,
          patient:
        )
      end

      it "doesn't invalidate the triage" do
        expect { perform }.not_to(change { triage.reload.invalidated? })
      end
    end

    context "with a delay vaccination triage that's not expired" do
      let(:triage) do
        create(
          :triage,
          :delay_vaccination,
          academic_year:,
          created_at: 1.day.ago,
          delay_vaccination_until: 28.days.from_now,
          team:,
          programme:,
          patient:
        )
      end

      it "doesn't invalidate the triage" do
        expect { perform }.not_to(change { triage.reload.invalidated? })
      end
    end

    context "if the patient was vaccinated" do
      before do
        create(
          :vaccination_record,
          team:,
          programme:,
          patient:,
          created_at: 1.day.ago
        )

        PatientStatusUpdater.call(patient:)
      end

      it "does not invalidate the consent" do
        expect { perform }.not_to(change { consent.reload.invalidated? })
      end

      context "with triage" do
        let(:triage) do
          create(
            :triage,
            :safe_to_vaccinate,
            academic_year:,
            created_at: 1.day.ago,
            team:,
            programme:,
            patient:
          )
        end

        it "does not invalidate the triage" do
          expect { perform }.not_to(change { triage.reload.invalidated? })
        end
      end
    end
  end

  context "with self-consent from today" do
    let(:consent) { create(:consent, :self_consent, academic_year:) }

    before { create(:patient_programme_status, patient:, programme:) }

    it "does not invalidate the consent" do
      expect { perform }.not_to(change { consent.reload.invalidated? })
    end

    context "with triage" do
      let(:triage) do
        create(
          :triage,
          :safe_to_vaccinate,
          academic_year:,
          team:,
          programme:,
          patient:
        )
      end

      it "does not invalidate the triage" do
        expect { perform }.not_to(change { triage.reload.invalidated? })
      end
    end
  end

  context "with two programmes, parental consent for one and self-consent for the other" do
    let(:parent_programme) { Programme.flu }
    let(:self_programme) { Programme.hpv }

    let(:team) { create(:team, programmes: [parent_programme, self_programme]) }

    let(:patient) { create(:patient) }

    let!(:self_consent) do
      create(
        :consent,
        :self_consent,
        patient:,
        academic_year:,
        created_at: 1.day.ago,
        programme: self_programme,
        team:
      )
    end
    let!(:parent_consent) do
      create(
        :consent,
        patient:,
        academic_year:,
        created_at: 1.day.ago,
        programme: parent_programme,
        team:
      )
    end

    before do
      create(
        :patient_programme_status,
        :due,
        patient:,
        programme: self_programme
      )
      create(
        :patient_programme_status,
        :due,
        patient:,
        programme: parent_programme
      )
    end

    it "does not invalidate the parent consent" do
      expect { perform }.not_to(change { parent_consent.reload.invalidated? })
    end

    it "invalidates the self-consent" do
      expect { perform }.to change { self_consent.reload.invalidated? }.from(
        false
      ).to(true)
    end
  end
end
