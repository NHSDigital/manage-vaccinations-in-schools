# frozen_string_literal: true

describe Stats::ConsentsBySchool do
  describe "#call" do
    subject(:service) do
      described_class.new(
        teams: [team],
        programme_types: %w[flu hpv],
        academic_year:
      )
    end

    let(:organisation) { create(:organisation, ods_code: "TEST003") }
    let(:programme_flu) { Programme.flu }
    let(:programme_hpv) { Programme.hpv }
    let(:programmes) { [programme_flu, programme_hpv] }

    let(:team) { create(:team, organisation:, name: "Test Team", programmes:) }
    let(:academic_year) { AcademicYear.current }
    let(:school) do
      create(:gias_school, name: "Test School", team:, programmes:)
    end

    context "when there are consent responses" do
      before do
        patient_location
        consent
      end

      let!(:session) do
        create(
          :session,
          team:,
          location: school,
          programmes: [programme_flu],
          academic_year:,
          send_consent_requests_at: 10.days.ago
        )
      end

      let!(:patient) { create(:patient, team:) }
      let(:patient_location) { create(:patient_location, session:, patient:) }

      let(:consent) do
        create(
          :consent,
          :given,
          patient:,
          academic_year:,
          programme: programme_flu,
          submitted_at: 8.days.ago,
          created_at: 8.days.ago
        )
      end

      it "returns structured consent data" do
        result = service.call

        expect(result).to have_key(:by_date)
        expect(result).to have_key(:by_days)
        expect(result).to have_key(:sessions)
        expect(result).to have_key(:by_days_sessions)
      end

      it "calculates by_date data correctly" do
        result = service.call
        response_date = 8.days.ago.to_date

        expect(result[:by_date]).to have_key(response_date)
        expect(result[:by_date][response_date]).to have_key(school)
        expect(result[:by_date][response_date][school]).to eq(1)
      end

      it "calculates by_days data correctly" do
        result = service.call
        days_difference = 2 # 10 days ago - 8 days ago

        expect(result[:by_days]).to have_key(days_difference)
        expect(result[:by_days][days_difference]).to have_key(school)
        expect(result[:by_days][days_difference][school]).to eq(1)
      end

      it "returns sessions with locations" do
        result = service.call

        expect(result[:sessions]).to include(session)
        expect(result[:sessions].first.location).to eq(school)
      end
    end

    context "when filtering by specific programmes" do
      subject(:flu_only_service) do
        described_class.new(
          teams: [team],
          programme_types: %w[flu],
          academic_year:
        )
      end

      let!(:flu_session) do
        create(
          :session,
          date: Date.new(AcademicYear.current, 12, 15),
          team:,
          location: school,
          programmes: [programme_flu],
          academic_year:,
          send_consent_requests_at: Date.new(AcademicYear.current, 12, 1)
        )
      end

      let!(:hpv_session) do
        create(
          :session,
          date: Date.new(AcademicYear.current, 11, 15),
          team:,
          location: school,
          programmes: [programme_hpv],
          academic_year:,
          send_consent_requests_at: Date.new(AcademicYear.current, 11, 1)
        )
      end

      it "only includes sessions for the specified programme" do
        result = flu_only_service.call

        expect(result[:sessions]).to include(flu_session)
        expect(result[:sessions]).not_to include(hpv_session)
      end
    end

    context "when filtering by academic year" do
      subject(:previous_year_service) do
        described_class.new(
          teams: [team],
          programme_types: %w[flu],
          academic_year: previous_year
        )
      end

      let(:current_year) { AcademicYear.current }
      let!(:current_year_session) do
        create(
          :session,
          team:,
          location: school,
          programmes: [programme_flu],
          academic_year: current_year
        )
      end
      let!(:previous_year_session) do
        school.import_year_groups_from_gias!(academic_year: previous_year)
        school.import_default_programme_year_groups!(
          programmes,
          academic_year: previous_year
        )

        create(
          :session,
          date: Date.new(AcademicYear.previous, 12, 15),
          team:,
          location: school,
          programmes: [programme_flu],
          academic_year: previous_year
        )
      end
      let(:previous_year) { current_year - 1 }

      it "only includes sessions for the specified academic year" do
        result = previous_year_service.call

        expect(result[:sessions]).to include(previous_year_session)
        expect(result[:sessions]).not_to include(current_year_session)
      end
    end

    context "when there are multiple consents for a patient" do
      before { patient_location }

      let!(:session) do
        create(
          :session,
          team:,
          location: school,
          programmes: [programme_flu, programme_hpv],
          academic_year:,
          send_consent_requests_at: 10.days.ago
        )
      end

      let!(:patient) { create(:patient, team:) }
      let(:patient_location) { create(:patient_location, session:, patient:) }

      let!(:flu_consent) do
        create(
          :consent,
          :given,
          patient:,
          academic_year:,
          programme: programme_flu,
          submitted_at: 8.days.ago,
          created_at: 8.days.ago
        )
      end

      let(:hpv_consent) do
        create(
          :consent,
          :given,
          patient:,
          academic_year:,
          programme: programme_hpv,
          submitted_at: 6.days.ago,
          created_at: 6.days.ago
        )
      end

      it "uses the earliest consent response for calculation" do
        result = service.call
        earliest_response_date = flu_consent.responded_at.to_date
        latest_response_date = hpv_consent.responded_at.to_date
        days_difference = 2 # 10 days ago - 8 days ago (earliest consent)

        expect(result[:by_date][earliest_response_date][school]).to eq(1)
        expect(result[:by_days][days_difference][school]).to eq(1)
        expect(result[:by_date]).not_to have_key(latest_response_date)
      end
    end
  end
end
