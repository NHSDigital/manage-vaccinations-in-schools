# frozen_string_literal: true

describe StatusGenerator::Consent do
  subject(:generator) do
    described_class.new(
      programme_type: programme.type,
      academic_year: AcademicYear.current,
      patient:,
      consents: patient.consents,
      vaccination_records: patient.vaccination_records,
      parents: patient.parents,
      sessions: [session],
      consent_notifications:
        patient.consent_notifications.includes(session: :team_location)
    )
  end

  let(:parents) { [create(:parent)] }
  let(:patient) { create(:patient, parents:) }
  let(:programme) { Programme.sample }
  let(:send_consent_requests_at) { nil }
  let(:session) do
    create(:session, programmes: [programme], send_consent_requests_at:)
  end

  describe "#status" do
    subject { generator.status }

    before do
      create(
        :consent_notification,
        :request,
        patient:,
        session:,
        programmes: [programme]
      )
    end

    context "when a request has not yet been sent" do
      before { ConsentNotification.delete_all }

      context "with consent requests scheduled" do
        let(:send_consent_requests_at) { 1.day.from_now }

        it { should be(:request_scheduled) }
      end

      context "with consent requests not scheduled" do
        it { should be(:request_not_scheduled) }
      end

      context "when consent requests scheduled date has already passed" do
        let(:send_consent_requests_at) { 1.day.ago.to_date }

        it { should be(:request_not_scheduled) }
      end
    end

    context "with no contactable parents" do
      let(:parents) { [] }

      it { should be(:no_contact_details) }
    end

    context "with no consent" do
      it { should be(:no_response) }
    end

    context "with an invalidated consent" do
      before { create(:consent, :invalidated, patient:, programme:) }

      it { should be(:no_response) }
    end

    context "with a not provided consent" do
      before { create(:consent, :not_provided, patient:, programme:) }

      it { should be(:no_response) }
    end

    context "with both an invalidated and not provided consent" do
      before do
        create(:consent, :invalidated, patient:, programme:)
        create(:consent, :not_provided, patient:, programme:)
      end

      it { should be(:no_response) }
    end

    context "with a refused consent" do
      before { create(:consent, :refused, patient:, programme:) }

      it { should be(:refused) }
    end

    context "with a follow_up_requested consent" do
      before { create(:consent, :follow_up_requested, patient:, programme:) }

      it { should be(:follow_up_requested) }
    end

    context "with a given consent" do
      before { create(:consent, :given, patient:, programme:) }

      it { should be(:given) }
    end

    context "with conflicting consent" do
      before do
        create(:consent, :given, patient:, programme:)
        create(
          :consent,
          :refused,
          patient:,
          programme:,
          parent: create(:parent)
        )
      end

      it { should be(:conflicts) }
    end

    context "with a given and follow_up_requested consent from different parents" do
      before do
        create(:consent, :given, patient:, programme:)
        create(
          :consent,
          :follow_up_requested,
          patient:,
          programme:,
          parent: create(:parent)
        )
      end

      it { should be(:follow_up_requested) }
    end

    context "with a refused and follow_up_requested consent from different parents" do
      before do
        create(:consent, :refused, patient:, programme:)
        create(
          :consent,
          :follow_up_requested,
          patient:,
          programme:,
          parent: create(:parent)
        )
      end

      it { should be(:conflicts) }
    end

    context "with two given consents with different methods" do
      before do
        create(
          :consent,
          :given,
          patient:,
          programme:,
          vaccine_methods: %w[injection]
        )
        create(
          :consent,
          :given,
          patient:,
          programme:,
          vaccine_methods: %w[nasal],
          parent: create(:parent)
        )
      end

      it { should be(:conflicts) }
    end

    context "with two given consents, one both and one with injection only" do
      before do
        create(
          :consent,
          :given,
          patient:,
          programme:,
          vaccine_methods: %w[injection]
        )
        create(
          :consent,
          :given,
          patient:,
          programme:,
          vaccine_methods: %w[nasal injection],
          parent: create(:parent)
        )
      end

      it { should be(:given) }
    end

    context "with an invalidated refused and given consent" do
      before do
        create(:consent, :refused, :invalidated, patient:, programme:)
        create(:consent, :given, patient:, programme:)
      end

      it { should be(:given) }
    end

    context "with a refused and given consent from the same parent at different times" do
      before do
        create(
          :consent,
          :refused,
          patient:,
          programme:,
          academic_year: AcademicYear.current,
          created_at: 1.day.ago,
          submitted_at: 2.days.ago
        )
        create(
          :consent,
          :given,
          patient:,
          programme:,
          academic_year: AcademicYear.current,
          created_at: 2.days.ago,
          submitted_at: 1.day.ago
        )
      end

      it { should be(:given) }
    end

    context "with self-consent" do
      before { create(:consent, :self_consent, :given, patient:, programme:) }

      it { should be(:given) }

      context "and refused parental consent" do
        before { create(:consent, :refused, patient:, programme:) }

        it { should be(:given) }
      end

      context "and conflicting parental consent" do
        before do
          create(:consent, :refused, patient:, programme:)
          create(
            :consent,
            :given,
            patient:,
            programme:,
            parent: create(:parent)
          )
        end

        it { should be(:given) }
      end
    end

    describe "academic year filtering" do
      let(:current_academic_year) { AcademicYear.current }
      let(:previous_academic_year) { current_academic_year - 1 }
      let(:patient) { create(:patient) }
      let(:programme) { Programme.sample }
      let(:parent) { create(:parent) }

      context "with a given consent from the current academic year" do
        before do
          create(
            :consent,
            :given,
            patient:,
            programme:,
            parent:,
            submitted_at: Date.new(current_academic_year, 10, 15).in_time_zone
          )
        end

        it { should be(:given) }
      end

      context "with a given consent from a previous academic year" do
        before do
          create(
            :consent,
            :given,
            patient:,
            programme:,
            parent: parent,
            submitted_at: Date.new(previous_academic_year, 10, 15).in_time_zone
          )
        end

        it { should be(:no_contact_details) }
      end

      context "with a given and refused consent from current and previous academic years" do
        before do
          create(
            :consent,
            :given,
            patient:,
            programme:,
            parent: parent,
            submitted_at: Date.new(current_academic_year, 10, 15).in_time_zone
          )
          create(
            :consent,
            :refused,
            patient:,
            programme:,
            parent: create(:parent),
            submitted_at: Date.new(previous_academic_year, 10, 15).in_time_zone
          )
        end

        it { should be(:given) }
      end

      context "with a refused and given consent from the current and previous academic years" do
        before do
          create(
            :consent,
            :refused,
            patient:,
            programme:,
            parent: parent,
            submitted_at: Date.new(current_academic_year, 10, 15).in_time_zone
          )
          create(
            :consent,
            :given,
            patient:,
            programme:,
            parent: create(:parent),
            submitted_at: Date.new(previous_academic_year, 10, 15).in_time_zone
          )
        end

        it { should be(:refused) }
      end
    end
  end

  describe "#vaccine_methods" do
    subject { generator.vaccine_methods }

    context "with no consent" do
      it { should be_empty }
    end

    context "with an invalidated consent" do
      before { create(:consent, :invalidated, patient:, programme:) }

      it { should be_empty }
    end

    context "with a not provided consent" do
      before { create(:consent, :not_provided, patient:, programme:) }

      it { should be_empty }
    end

    context "with both an invalidated and not provided consent" do
      before do
        create(:consent, :invalidated, patient:, programme:)
        create(:consent, :not_provided, patient:, programme:)
      end

      it { should be_empty }
    end

    context "with a refused consent" do
      before { create(:consent, :refused, patient:, programme:) }

      it { should be_empty }
    end

    context "with a follow_up_requested consent" do
      before { create(:consent, :follow_up_requested, patient:, programme:) }

      it { should be_empty }
    end

    context "with an injection given consent" do
      before do
        create(
          :consent,
          :given,
          patient:,
          programme:,
          vaccine_methods: %w[injection]
        )
      end

      it { should contain_exactly("injection") }
    end

    context "with a nasal given consent" do
      before do
        create(
          :consent,
          :given,
          patient:,
          programme:,
          vaccine_methods: %w[nasal]
        )
      end

      it { should contain_exactly("nasal") }
    end

    context "with both nasal and injection given consent" do
      before do
        create(
          :consent,
          :given,
          patient:,
          programme:,
          vaccine_methods: %w[nasal injection]
        )
      end

      it { should eq(%w[nasal injection]) }
    end

    context "with one parent nasal and one parent both" do
      before do
        create(
          :consent,
          :given,
          patient:,
          programme:,
          vaccine_methods: %w[nasal]
        )
        create(
          :consent,
          :given,
          patient:,
          programme:,
          parent: create(:parent),
          vaccine_methods: %w[nasal injection]
        )
      end

      it { should contain_exactly("nasal") }
    end

    context "with conflicting consent" do
      before do
        create(:consent, :given, patient:, programme:)
        create(
          :consent,
          :refused,
          patient:,
          programme:,
          parent: create(:parent)
        )
      end

      it { should be_empty }
    end

    context "with an invalidated refused and given consent" do
      before do
        create(:consent, :refused, :invalidated, patient:, programme:)
        create(:consent, :given, patient:, programme:)
      end

      it { should contain_exactly("injection") }
    end

    context "with self-consent" do
      before { create(:consent, :self_consent, :given, patient:, programme:) }

      it { should contain_exactly("injection") }

      context "and refused parental consent" do
        before { create(:consent, :refused, patient:, programme:) }

        it { should contain_exactly("injection") }
      end

      context "and conflicting parental consent" do
        before do
          create(:consent, :refused, patient:, programme:)
          create(
            :consent,
            :given,
            patient:,
            programme:,
            parent: create(:parent)
          )
        end

        it { should contain_exactly("injection") }
      end
    end
  end

  describe "#without_gelatine" do
    subject { generator.without_gelatine }

    let(:programme) { Programme.mmr }

    context "with no consent" do
      it { should be_nil }
    end

    context "with an invalidated consent" do
      before { create(:consent, :invalidated, patient:, programme:) }

      it { should be_nil }
    end

    context "with a not provided consent" do
      before { create(:consent, :not_provided, patient:, programme:) }

      it { should be_nil }
    end

    context "with both an invalidated and not provided consent" do
      before do
        create(:consent, :invalidated, patient:, programme:)
        create(:consent, :not_provided, patient:, programme:)
      end

      it { should be_nil }
    end

    context "with a refused consent" do
      before { create(:consent, :refused, patient:, programme:) }

      it { should be_nil }
    end

    context "with a follow_up_requested consent" do
      before { create(:consent, :follow_up_requested, patient:, programme:) }

      it { should be_nil }
    end

    context "with a given consent" do
      before { create(:consent, :given, patient:, programme:) }

      it { should be(false) }
    end

    context "with a without gelatine given consent" do
      before do
        create(:consent, :given, :without_gelatine, patient:, programme:)
      end

      it { should be(true) }
    end

    context "with a with and without gelatine given consent" do
      before do
        create(:consent, :given, patient:, programme:)
        create(
          :consent,
          :given,
          :without_gelatine,
          patient:,
          programme:,
          parent: create(:parent)
        )
      end

      it { should be(true) }
    end
  end

  describe "#disease_types" do
    subject { generator.disease_types }

    context "with no consent" do
      it { should be_empty }
    end

    context "with an invalidated consent" do
      before { create(:consent, :invalidated, patient:, programme:) }

      it { should be_empty }
    end

    context "with a not provided consent" do
      before { create(:consent, :not_provided, patient:, programme:) }

      it { should be_empty }
    end

    context "with both an invalidated and not provided consent" do
      before do
        create(:consent, :invalidated, patient:, programme:)
        create(:consent, :not_provided, patient:, programme:)
      end

      it { should be_empty }
    end

    context "with a refused consent" do
      before { create(:consent, :refused, patient:, programme:) }

      it { should be_empty }
    end

    context "with MMR disease types" do
      let(:disease_types) { Programme::DISEASE_TYPES["mmr"] }

      before { create(:consent, :given, patient:, programme:, disease_types:) }

      it { should eq(disease_types) }
    end

    context "with conflicting consent" do
      before do
        create(:consent, :given, patient:, programme:)
        create(
          :consent,
          :refused,
          patient:,
          programme:,
          parent: create(:parent)
        )
      end

      it { should be_empty }
    end

    context "with an invalidated refused and given consent" do
      let(:refused_disease_types) { Programme::Variant::DISEASE_TYPES["mmrv"] }
      let(:given_disease_types) { Programme::DISEASE_TYPES["mmr"] }

      before do
        create(
          :consent,
          :refused,
          :invalidated,
          patient:,
          programme:,
          disease_types: refused_disease_types
        )
        create(
          :consent,
          :given,
          patient:,
          programme:,
          disease_types: given_disease_types
        )
      end

      it { should eq(given_disease_types) }
    end

    context "with self-consent" do
      let(:disease_types) { Programme::DISEASE_TYPES["mmr"] }

      before do
        create(
          :consent,
          :self_consent,
          :given,
          patient:,
          programme:,
          disease_types:
        )
      end

      it { should eq(disease_types) }

      context "and refused parental consent" do
        before do
          create(:consent, :refused, patient:, programme:, disease_types:)
        end

        it { should eq(disease_types) }
      end

      context "and conflicting parental consent" do
        let(:refused_disease_types) do
          Programme::Variant::DISEASE_TYPES["mmrv"]
        end
        let(:given_disease_types) { Programme::DISEASE_TYPES["mmr"] }

        before do
          create(
            :consent,
            :refused,
            patient:,
            programme:,
            disease_types: refused_disease_types
          )
          create(
            :consent,
            :given,
            patient:,
            programme:,
            parent: create(:parent),
            disease_types: given_disease_types
          )
        end

        it { should eq(given_disease_types) }
      end
    end
  end
end
