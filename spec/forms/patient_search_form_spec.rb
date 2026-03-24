# frozen_string_literal: true

describe PatientSearchForm do
  subject(:form) do
    described_class.new(
      current_user:,
      request_session:,
      request_path:,
      session:,
      **params
    )
  end

  around { |example| travel_to(Date.new(2025, 7, 31)) { example.run } }

  let(:current_user) { create(:user, teams: [team]) }
  let(:request_session) { {} }
  let(:request_path) { "/patients" }
  let(:session) { nil }

  let(:programme) { Programme.flu }
  let(:programmes) { [programme] }
  let(:team) { create(:team, programmes:) }

  let(:aged_out_of_programmes) { nil }
  let(:archived) { nil }
  let(:date_of_birth_day) { nil }
  let(:date_of_birth_month) { nil }
  let(:date_of_birth_year) { nil }
  let(:invited_to_clinic) { nil }
  let(:missing_nhs_number) { nil }
  let(:patient_specific_direction_status) { nil }
  let(:programme_statuses) { nil }
  let(:programme_types) { nil }
  let(:q) { nil }
  let(:registration_status) { nil }
  let(:vaccine_criteria) { nil }
  let(:year_groups) { nil }

  let(:params) do
    {
      aged_out_of_programmes:,
      archived:,
      date_of_birth_day:,
      date_of_birth_month:,
      date_of_birth_year:,
      invited_to_clinic:,
      missing_nhs_number:,
      patient_specific_direction_status:,
      programme_statuses:,
      programme_types:,
      q:,
      registration_status:,
      vaccine_criteria:,
      year_groups:
    }
  end

  describe "#apply" do
    let(:scope) { Patient.all }

    let(:session_for_patients) { create(:session, team:, programmes:) }

    it "doesn't raise an error" do
      expect { form.apply(scope) }.not_to raise_error
    end

    context "filtering on aged out of programmes" do
      let(:programmes) { [Programme.flu] }
      let(:location) do
        create(:gias_school, programmes:, gias_year_groups: [11, 12])
      end
      let(:session_for_patients) { create(:session, location:, programmes:) }

      let!(:aged_out_patient) do
        create(:patient, session: session_for_patients, year_group: 12)
      end
      let!(:not_aged_out_patient) do
        create(:patient, session: session_for_patients, year_group: 11)
      end

      context "when not filtering on aged out patients" do
        it "includes the not aged out patient" do
          expect(form.apply(scope)).to include(not_aged_out_patient)
        end

        it "doesn't include the aged out patient" do
          expect(form.apply(scope)).not_to include(aged_out_patient)
        end
      end

      context "when filtering on aged out patients" do
        let(:aged_out_of_programmes) { true }

        it "doesn't include the not aged out patient" do
          expect(form.apply(scope)).not_to include(not_aged_out_patient)
        end

        it "includes the aged out patient" do
          expect(form.apply(scope)).to include(aged_out_patient)
        end
      end
    end

    context "filtering on archived" do
      let!(:unarchived_patient) do
        create(:patient, session: session_for_patients)
      end
      let!(:archived_patient) { create(:patient) }

      before do
        create(:archive_reason, :deceased, team:, patient: archived_patient)
      end

      context "when not filtering on archived patients" do
        it "includes the unarchived patient" do
          expect(form.apply(scope)).to include(unarchived_patient)
        end

        it "doesn't include the archived patient" do
          expect(form.apply(scope)).not_to include(archived_patient)
        end
      end

      context "when filtering on archived patients" do
        let(:archived) { true }

        it "doesn't include the unarchived patient" do
          expect(form.apply(scope)).not_to include(unarchived_patient)
        end

        it "includes the archived patient" do
          expect(form.apply(scope)).to include(archived_patient)
        end
      end
    end

    context "filtering on date of birth" do
      let(:patient) do
        create(
          :patient,
          session: session_for_patients,
          date_of_birth: Date.new(2000, 1, 1)
        )
      end

      context "with only a year specified" do
        let(:date_of_birth_year) { 2000 }

        it "includes the patient" do
          expect(form.apply(scope)).to include(patient)
        end
      end

      context "with only a month specified" do
        let(:date_of_birth_month) { 1 }

        it "includes the patient" do
          expect(form.apply(scope)).to include(patient)
        end
      end

      context "with only a day specified" do
        let(:date_of_birth_day) { 1 }

        it "includes the patient" do
          expect(form.apply(scope)).to include(patient)
        end
      end

      context "with all parts specified" do
        let(:date_of_birth_year) { 2000 }
        let(:date_of_birth_month) { 1 }
        let(:date_of_birth_day) { 1 }

        it "includes the patient" do
          expect(form.apply(scope)).to include(patient)
        end
      end
    end

    context "filtering on invited_to_clinic" do
      let!(:patient_with_clinic_notification) do
        create(:patient, session: session_for_patients)
      end
      let!(:patient_without_clinic_notification) do
        create(:patient, session: session_for_patients)
      end

      before do
        create(
          :clinic_notification,
          :initial_invitation,
          patient: patient_with_clinic_notification,
          team:,
          academic_year: AcademicYear.pending,
          programmes:
        )
      end

      context "when the value is true" do
        let(:invited_to_clinic) { true }

        it "includes the patient with clinic notification" do
          expect(form.apply(scope)).to include(patient_with_clinic_notification)
        end

        it "doesn't include the patient without clinic notification" do
          expect(form.apply(scope)).not_to include(
            patient_without_clinic_notification
          )
        end
      end

      context "when the value is false" do
        let(:invited_to_clinic) { false }

        it "includes both patients" do
          expect(form.apply(scope)).to include(patient_with_clinic_notification)
          expect(form.apply(scope)).to include(
            patient_without_clinic_notification
          )
        end
      end
    end

    context "filtering on name" do
      let(:patient_a) do
        create(
          :patient,
          given_name: "Harry",
          family_name: "Potter",
          session: session_for_patients
        )
      end
      let(:patient_b) do
        create(
          :patient,
          given_name: "Hari",
          family_name: "Potter",
          session: session_for_patients
        )
      end
      let(:patient_c) do
        create(
          :patient,
          given_name: "Arry",
          family_name: "Pott",
          session: session_for_patients
        )
      end
      let(:patient_d) do
        create(
          :patient,
          given_name: "Ron",
          family_name: "Weasley",
          session: session_for_patients
        )
      end
      let(:patient_e) do
        create(
          :patient,
          given_name: "Ginny",
          family_name: "Weasley",
          session: session_for_patients
        )
      end

      context "with no search query" do
        let(:q) { nil }

        it "sorts alphabetically by name" do
          expect(form.apply(scope)).to eq(
            [patient_c, patient_b, patient_a, patient_e, patient_d]
          )
        end
      end

      context "with some search query" do
        let(:q) { "Harry Potter" }

        it "sorts by similarity" do
          expect(form.apply(scope)).to eq([patient_a, patient_b, patient_c])
        end
      end
    end

    context "filtering on patient specific direction status" do
      let(:session) { session_for_patients }

      let!(:patient_with_psd) { create(:patient, session:) }
      let!(:patient_without_psd) { create(:patient, session:) }

      before do
        create(
          :patient_specific_direction,
          patient: patient_with_psd,
          programme: programmes.first,
          team:
        )
      end

      context "when status is 'added'" do
        let(:patient_specific_direction_status) { "added" }

        it "finds the patient with the PSD" do
          expect(form.apply(scope)).to contain_exactly(patient_with_psd)
        end
      end

      context "when status is 'not_added'" do
        let(:patient_specific_direction_status) { "not_added" }

        it "finds the patient that has no PSD" do
          expect(form.apply(scope)).to contain_exactly(patient_without_psd)
        end
      end
    end

    context "filtering on programmes" do
      let(:programme_types) { programmes.map(&:type) }

      let(:programme) { Programme.menacwy }
      let(:programmes) { [programme] }

      context "with a patient eligible for the programme" do
        let(:patient) { create(:patient, session: session_for_patients) }

        it "is included" do
          expect(form.apply(scope)).to include(patient)
        end
      end

      context "with a patient not eligible for the programme" do
        let(:patient) do
          create(:patient, session: session_for_patients, year_group: 8)
        end

        it "is not included" do
          expect(form.apply(scope)).not_to include(patient)
        end
      end
    end

    context "filtering on register status" do
      let(:registration_status) { "attending" }

      let(:session) { session_for_patients }

      it "filters on register status" do
        patient = create(:patient, :in_attendance, session:)
        expect(form.apply(scope)).to include(patient)
      end
    end

    context "filtering on vaccine criteria" do
      let(:programmes) { [Programme.flu] }
      let(:programme_types) { programmes.map(&:type) }

      let(:vaccine_criteria) { %w[flu_nasal_injection] }

      let(:session) { session_for_patients }

      it "filters on vaccine method" do
        nasal_patient =
          create(:patient, :consent_given_triage_not_needed, session:)

        nasal_patient.programme_statuses.first.update!(
          vaccine_methods: %w[nasal injection]
        )

        _nasal_only_different_programme_patient =
          create(
            :patient,
            :consent_given_triage_not_needed,
            programmes: [Programme.hpv]
          )

        _injection_only_patient =
          create(:patient, :consent_given_triage_not_needed, session:)

        injection_primary_patient =
          create(:patient, :consent_given_triage_not_needed, session:)

        injection_primary_patient.programme_statuses.first.update!(
          vaccine_methods: %w[injection nasal]
        )

        expect(form.apply(scope)).to contain_exactly(nasal_patient)
      end
    end
  end

  describe "session filter persistence" do
    let(:another_path) { "/another-path" }

    context "when _clear param is present" do
      it "only clears filters for the current path" do
        described_class.new(
          current_user:,
          request_path:,
          request_session:,
          "q" => "John"
        )

        described_class.new(
          current_user:,
          request_path: another_path,
          request_session:,
          q: "Jane"
        )

        described_class.new(
          current_user:,
          request_path:,
          request_session:,
          "_clear" => "true"
        )

        form1 =
          described_class.new(current_user:, request_session:, request_path:)
        expect(form1.q).to be_nil

        form2 =
          described_class.new(
            current_user:,
            request_session:,
            request_path: another_path
          )
        expect(form2.q).to eq("Jane")
      end
    end

    context "when filters are present in params" do
      it "persists filters to be loaded in subsequent requests" do
        described_class.new(
          current_user:,
          q: "John",
          request_session:,
          request_path:
        )

        form =
          described_class.new(current_user:, request_session:, request_path:)
        expect(form.q).to eq("John")
      end

      it "overwrites previously stored filters" do
        described_class.new(
          current_user:,
          q: "John",
          request_session:,
          request_path:
        )

        form1 =
          described_class.new(
            current_user:,
            q: "Jane",
            request_session:,
            request_path:
          )
        expect(form1.q).to eq("Jane")

        form2 =
          described_class.new(current_user:, request_session:, request_path:)
        expect(form2.q).to eq("Jane")
      end

      it "overrides session filters when 'Any' option is selected (empty string)" do
        described_class.new(
          current_user:,
          programme_statuses: %w[needs_triage],
          request_session:,
          request_path:
        )

        form1 =
          described_class.new(current_user:, request_session:, request_path:)
        expect(form1.programme_statuses).to eq(%w[needs_triage])

        form2 =
          described_class.new(
            current_user:,
            programme_statuses: nil,
            request_session:,
            request_path:
          )
        expect(form2.programme_statuses).to eq([])

        form3 =
          described_class.new(current_user:, request_session:, request_path:)
        expect(form3.programme_statuses).to eq([])
      end
    end

    context "when no filters are present in params but exist in session" do
      before do
        described_class.new(
          current_user:,
          q: "John",
          year_groups: %w[8 11],
          programme_statuses: %w[needs_triage],
          request_session:,
          request_path:
        )
      end

      it "loads filters from the session" do
        form =
          described_class.new(current_user:, request_session:, request_path:)

        expect(form.q).to eq("John")
        expect(form.year_groups).to eq([8, 11])
        expect(form.programme_statuses).to eq(%w[needs_triage])
      end
    end

    context "with path-specific filters" do
      it "maintains separate filters for different paths" do
        described_class.new(
          current_user:,
          q: "John",
          request_session:,
          request_path:
        )
        described_class.new(
          current_user:,
          q: "Jane",
          request_session:,
          request_path: another_path
        )

        form1 =
          described_class.new(current_user:, request_session:, request_path:)
        expect(form1.q).to eq("John")

        form2 =
          described_class.new(
            current_user:,
            request_session:,
            request_path: another_path
          )
        expect(form2.q).to eq("Jane")
      end
    end
  end

  context "using PatientPolicy scope" do
    let(:missing_nhs_number) { false }
    let(:programme_types) { programmes.map(&:type) }

    let(:team) { create(:team) }
    let(:programme) { Programme.flu }
    let(:subteam) { create(:subteam, team:) }
    let(:user) { create(:user, team:) }
    let(:patient) { create(:patient) }
    let(:scope) { PatientPolicy::Scope.new(user, Patient).resolve }

    context "when patient has a school move but is not part of the programme" do
      before do
        create(
          :school_move,
          :to_school,
          patient:,
          school: create(:gias_school, subteam:)
        )
      end

      it "does not include the patient" do
        expect(form.apply(scope)).not_to include(patient)
      end
    end

    context "when patient has a vaccination record not associated with the programme" do
      before do
        create(
          :vaccination_record,
          patient:,
          performed_ods_code: team.organisation.ods_code,
          programme: Programme.hpv
        )
      end

      it "does not include the patient" do
        expect(form.apply(scope)).not_to include(patient)
      end
    end
  end
end
