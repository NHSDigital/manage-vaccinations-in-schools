# frozen_string_literal: true

describe StatusGenerator::Triage do
  subject(:generator) do
    described_class.new(
      programme_type: programme.type,
      academic_year: current_academic_year,
      patient:,
      consents: patient.consents,
      triages: patient.triages,
      vaccination_records: patient.vaccination_records,
      parents: patient.parents,
      sessions: [],
      consent_notifications: patient.consent_notifications.request
    )
  end

  let(:current_academic_year) { AcademicYear.current }
  let(:patient) { create(:patient) }
  let(:programme) { Programme.hpv }

  describe "#status" do
    subject { generator.status }

    context "with no triage" do
      it { should be(:not_required) }
    end

    context "with conflicting consent" do
      before do
        create(:consent, :given, patient:, programme:)
        create(
          :consent,
          :refused,
          :needing_triage,
          patient:,
          programme:,
          parent: create(:parent)
        )
      end

      it { should be(:not_required) }
    end

    context "with two given consents with different methods" do
      before do
        create(
          :consent,
          :given,
          :needing_triage,
          patient:,
          programme:,
          vaccine_methods: %w[injection]
        )
        create(
          :consent,
          :given,
          :needing_triage,
          patient:,
          programme:,
          vaccine_methods: %w[nasal],
          parent: create(:parent)
        )
      end

      it { should be(:not_required) }
    end

    context "with a consent that needs triage" do
      before { create(:consent, :needing_triage, patient:, programme:) }

      it { should be(:required) }
    end

    context "with a historical vaccination that needs triage" do
      let(:programme) { Programme.td_ipv }

      before do
        create(:vaccination_record, patient:, programme:, dose_sequence: 1)
      end

      it { should be(:not_required) }

      context "when consent is given" do
        before { create(:consent, :given, patient:, programme:) }

        it { should be(:required) }
      end

      context "when consent is refused" do
        before { create(:consent, :refused, patient:, programme:) }

        it { should be(:not_required) }
      end
    end

    context "with a historical vaccination that doesn't need triage" do
      let(:programme) { Programme.mmr }

      before do
        create(:vaccination_record, patient:, programme:, dose_sequence: 1)
      end

      it { should be(:not_required) }

      context "when consent is given" do
        before { create(:consent, :given, patient:, programme:) }

        it { should be(:not_required) }
      end

      context "when consent is refused" do
        before { create(:consent, :refused, patient:, programme:) }

        it { should be(:not_required) }
      end
    end

    context "with a safe to vaccinate triage" do
      before { create(:triage, :safe_to_vaccinate, patient:, programme:) }

      it { should be(:safe_to_vaccinate) }
    end

    context "with a do not vaccinate triage" do
      before { create(:triage, :do_not_vaccinate, patient:, programme:) }

      it { should be(:do_not_vaccinate) }
    end

    context "with a needs follow up triage" do
      before { create(:triage, :keep_in_triage, patient:, programme:) }

      it { should be(:required) }
    end

    context "with a delay vaccination triage" do
      before { create(:triage, :delay_vaccination, patient:, programme:) }

      it { should be(:delay_vaccination) }
    end

    context "with a delay vaccination which expires in the future" do
      before do
        create(
          :triage,
          :delay_vaccination,
          delay_vaccination_until: Date.tomorrow,
          patient:,
          programme:
        )
      end

      it { should be(:delay_vaccination) }
    end

    context "with a delay vaccination which has since expired" do
      before do
        create(
          :triage,
          :delay_vaccination,
          delay_vaccination_until: Date.yesterday,
          patient:,
          programme:
        )
      end

      it { should be(:required) }
    end

    context "with an invalidated safe to vaccinate triage" do
      before do
        create(:triage, :safe_to_vaccinate, :invalidated, patient:, programme:)
      end

      it { should be(:not_required) }
    end

    context "when the patient is already vaccinated" do
      shared_examples "a vaccinated patient with any triage status" do
        before do
          create(:triage, triage_trait, patient:, programme:) if triage_trait
        end

        it { should be(:not_required) }
      end

      before { create(:vaccination_record, patient:, programme:) }

      context "with a safe to vaccinate triage" do
        it_behaves_like "a vaccinated patient with any triage status" do
          let(:triage_trait) { :safe_to_vaccinate }
        end
      end

      context "with a do not vaccinate triage" do
        it_behaves_like "a vaccinated patient with any triage status" do
          let(:triage_trait) { :do_not_vaccinate }
        end
      end

      context "with a needs follow up triage" do
        it_behaves_like "a vaccinated patient with any triage status" do
          let(:triage_trait) { :keep_in_triage }
        end
      end

      context "with a delay vaccination triage" do
        it_behaves_like "a vaccinated patient with any triage status" do
          let(:triage_trait) { :delay_vaccination }
        end
      end
    end

    describe "academic year filtering" do
      let(:previous_academic_year) { current_academic_year - 1 }
      let(:patient) { create(:patient) }
      let(:programme) { Programme.sample }

      context "with a ready to vaccinate triage from the current academic year" do
        before do
          create(
            :triage,
            :safe_to_vaccinate,
            patient:,
            programme:,
            created_at: Date.new(current_academic_year, 10, 15).in_time_zone
          )
        end

        it { should be(:safe_to_vaccinate) }
      end

      context "with a ready to vaccinate triage from a previous academic year" do
        before do
          create(
            :triage,
            :safe_to_vaccinate,
            patient:,
            programme:,
            created_at: Date.new(previous_academic_year, 10, 15).in_time_zone
          )
        end

        it { should be(:not_required) }
      end

      context "with a ready to vaccinate and a do not vaccinate triage from the current and previous academic years" do
        before do
          create(
            :triage,
            :safe_to_vaccinate,
            patient:,
            programme:,
            created_at: Date.new(current_academic_year, 10, 15).in_time_zone
          )
          create(
            :triage,
            :do_not_vaccinate,
            patient:,
            programme:,
            created_at: Date.new(previous_academic_year, 10, 15).in_time_zone
          )
        end

        it { should be(:safe_to_vaccinate) }
      end

      context "with a do not vaccinate and ready to vaccinate triage from the current and previous academic years" do
        before do
          create(
            :triage,
            :do_not_vaccinate,
            patient:,
            programme:,
            created_at: Date.new(current_academic_year, 10, 15).in_time_zone
          )
          create(
            :triage,
            :safe_to_vaccinate,
            patient:,
            programme:,
            created_at: Date.new(previous_academic_year, 10, 15).in_time_zone
          )
        end

        it { should be(:do_not_vaccinate) }
      end
    end
  end

  describe "#vaccine_method" do
    subject { generator.vaccine_method }

    context "with no triage" do
      it { should be_nil }
    end

    context "with a consent that needs triage" do
      before { create(:consent, :needing_triage, patient:, programme:) }

      it { should be_nil }
    end

    context "with a historical vaccination that needs triage" do
      let(:programme) { Programme.td_ipv }

      before do
        create(:vaccination_record, patient:, programme:, dose_sequence: 1)
      end

      it { should be_nil }

      context "when consent is given" do
        before { create(:consent, :given, patient:, programme:) }

        it { should be_nil }
      end

      context "when consent is refused" do
        before { create(:consent, :refused, patient:, programme:) }

        it { should be_nil }
      end
    end

    context "with a safe to vaccinate triage" do
      before { create(:triage, :safe_to_vaccinate, patient:, programme:) }

      it { should eq("injection") }
    end

    context "with a safe to vaccinate triage and vaccinated" do
      before do
        create(:triage, :safe_to_vaccinate, patient:, programme:)
        create(:vaccination_record, patient:, programme:)
      end

      it { should be_nil }
    end

    context "with a do not vaccinate triage" do
      before { create(:triage, :do_not_vaccinate, patient:, programme:) }

      it { should be_nil }
    end

    context "with a needs follow up triage" do
      before { create(:triage, :keep_in_triage, patient:, programme:) }

      it { should be_nil }
    end

    context "with a delay vaccination triage" do
      before { create(:triage, :delay_vaccination, patient:, programme:) }

      it { should be_nil }
    end

    context "with an invalidated safe to vaccinate triage" do
      before do
        create(:triage, :safe_to_vaccinate, :invalidated, patient:, programme:)
      end

      it { should be_nil }
    end
  end

  describe "#created_at" do
    subject { generator.created_at }

    context "with no triage" do
      it { should be_nil }
    end

    context "with a safe to vaccinate triage" do
      let!(:triage) do
        create(:triage, :safe_to_vaccinate, patient:, programme:)
      end

      it { should eq(triage.created_at) }
    end

    context "with a safe to vaccinate triage and vaccinated" do
      let!(:triage) do
        create(:triage, :safe_to_vaccinate, patient:, programme:)
      end

      before { create(:vaccination_record, patient:, programme:) }

      it { should eq(triage.created_at) }
    end

    context "with a do not vaccinate triage" do
      let!(:triage) { create(:triage, :do_not_vaccinate, patient:, programme:) }

      it { should eq(triage.created_at) }
    end

    context "with multiple triages" do
      let!(:latest_triage) do
        create(
          :triage,
          :safe_to_vaccinate,
          patient:,
          programme:,
          created_at: latest_created_at
        )
      end

      let(:older_created_at) do
        Date.new(current_academic_year, 10, 15).in_time_zone
      end

      let(:latest_created_at) { older_created_at + 2.days }

      before do
        create(
          :triage,
          :safe_to_vaccinate,
          patient:,
          programme:,
          created_at: older_created_at
        )
      end

      it { should eq(latest_triage.created_at) }
    end

    context "with an invalidated safe to vaccinate triage" do
      before do
        create(:triage, :safe_to_vaccinate, :invalidated, patient:, programme:)
      end

      it { should be_nil }
    end
  end

  describe "#without_gelatine" do
    subject { generator.without_gelatine }

    let(:programme) { Programme.mmr }

    context "with no triage" do
      it { should be_nil }
    end

    context "with a do not vaccinate triage" do
      before { create(:triage, :do_not_vaccinate, patient:, programme:) }

      it { should be_nil }
    end

    context "with a safe to vaccinate triage with gelatine" do
      before do
        create(
          :triage,
          :safe_to_vaccinate,
          patient:,
          programme:,
          without_gelatine: false
        )
      end

      it { should be(false) }
    end

    context "with a safe to vaccinate triage without gelatine" do
      before do
        create(
          :triage,
          :safe_to_vaccinate_without_gelatine,
          patient:,
          programme:
        )
      end

      it { should be(true) }
    end
  end
end
