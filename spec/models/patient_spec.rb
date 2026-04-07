# frozen_string_literal: true

# == Schema Information
#
# Table name: patients
#
#  id                         :bigint           not null, primary key
#  address_line_1             :string
#  address_line_2             :string
#  address_postcode           :string
#  address_town               :string
#  birth_academic_year        :integer          not null
#  date_of_birth              :date             not null
#  date_of_death              :date
#  date_of_death_recorded_at  :datetime
#  ethnic_background          :integer
#  ethnic_background_other    :string
#  ethnic_group               :integer
#  family_name                :string           not null
#  gender_code                :integer          default("not_known"), not null
#  given_name                 :string           not null
#  invalidated_at             :datetime
#  local_authority_mhclg_code :string
#  nhs_number                 :string
#  pending_changes            :jsonb            not null
#  preferred_family_name      :string
#  preferred_given_name       :string
#  registration               :string
#  registration_academic_year :integer
#  restricted_at              :datetime
#  updated_from_pds_at        :datetime
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  gp_practice_id             :bigint
#  school_id                  :bigint
#
# Indexes
#
#  index_patients_on_family_name_trigram                  (family_name) USING gin
#  index_patients_on_given_name_trigram                   (given_name) USING gin
#  index_patients_on_gp_practice_id                       (gp_practice_id)
#  index_patients_on_local_authority_mhclg_code           (local_authority_mhclg_code)
#  index_patients_on_lower_family_name_dob_address        (date_of_birth, address_postcode, lower((family_name)::text))
#  index_patients_on_lower_given_name_dob_address         (address_postcode, date_of_birth, lower((given_name)::text))
#  index_patients_on_lower_names_family_first_address     (lower((family_name)::text), lower((given_name)::text), address_postcode)
#  index_patients_on_lower_names_given_first_dob_address  (lower((given_name)::text), lower((family_name)::text), date_of_birth, address_postcode)
#  index_patients_on_names_family_first                   (family_name,given_name)
#  index_patients_on_names_given_first                    (given_name,family_name)
#  index_patients_on_nhs_number                           (nhs_number) UNIQUE
#  index_patients_on_pending_changes_not_empty            (id) WHERE (pending_changes <> '{}'::jsonb)
#  index_patients_on_school_id                            (school_id)
#
# Foreign Keys
#
#  fk_rails_...  (gp_practice_id => locations.id)
#  fk_rails_...  (school_id => locations.id)
#

describe Patient do
  describe "associations" do
    it { should have_many(:archive_reasons) }

    describe "#vaccination_records" do
      subject(:vaccination_records) { patient.vaccination_records }

      let(:patient) { create(:patient) }
      let(:programme) { Programme.sample }
      let(:kept_vaccination_record) do
        create(:vaccination_record, patient:, programme:)
      end
      let(:discarded_vaccination_record) do
        create(:vaccination_record, :discarded, patient:, programme:)
      end

      it { should include(kept_vaccination_record) }
      it { should_not include(discarded_vaccination_record) }
    end
  end

  describe "scopes" do
    describe "#joins_sessions" do
      subject(:scope) { described_class.joins_sessions }

      let(:patient) { create(:patient) }

      it { should be_empty }

      context "when a patient belongs to a session with no dates" do
        let(:session) { create(:session, :unscheduled) }

        before { create(:patient_location, patient:, session:) }

        it { should include(patient) }
      end

      context "when the session has a date" do
        let(:session) { create(:session, :today) }

        context "and the patient location has no date range" do
          before { create(:patient_location, patient:, session:) }

          it { should include(patient) }
        end

        context "and the patient location is outside the range" do
          before do
            create(
              :patient_location,
              patient:,
              session:,
              date_range: ..Date.yesterday
            )
          end

          it { should_not include(patient) }
        end

        context "and the patient location is inside the range" do
          before do
            create(
              :patient_location,
              patient:,
              session:,
              date_range: Date.current..
            )
          end

          it { should include(patient) }
        end
      end
    end

    describe "#archived" do
      subject(:scope) { described_class.archived(team:) }

      let(:patient) { create(:patient) }
      let(:team) { create(:team) }

      context "without an archive reason" do
        before { create(:patient_team, team:, patient:) }

        it { should_not include(patient) }
      end

      context "with an archive reason for the team" do
        before { create(:patient_team, :archive_reason, team:, patient:) }

        it { should include(patient) }
      end

      context "with an archive reason for a different team" do
        before do
          create(:patient_team, team:, patient:)
          create(:patient_team, :archive_reason, team: create(:team), patient:)
        end

        it { should_not include(patient) }
      end
    end

    describe "#not_archived" do
      subject(:scope) { described_class.not_archived(team:) }

      let(:patient) { create(:patient) }
      let(:team) { create(:team) }

      context "without an archive reason" do
        before { create(:patient_team, team:, patient:) }

        it { should include(patient) }
      end

      context "with an archive reason for the team" do
        before { create(:patient_team, :archive_reason, team:, patient:) }

        it { should_not include(patient) }
      end

      context "with an archive reason for a different team" do
        before do
          create(:patient_team, team:, patient:)
          create(:patient_team, :archive_reason, team: create(:team), patient:)
        end

        it { should include(patient) }
      end
    end

    describe "#with_pending_changes" do
      subject(:scope) { described_class.with_pending_changes_for_team(team:) }

      let(:team) { create(:team) }
      let(:patient) { create(:patient) }

      before { create(:patient_team, team:, patient:) }

      context "without pending changes" do
        it { should_not include(patient) }
      end

      context "with pending changes" do
        before do
          patient.update!(pending_changes: { "some_field" => "new_value" })
        end

        it { should include(patient) }
      end

      context "with pending changes but archived from the team" do
        before do
          patient.update!(pending_changes: { "some_field" => "new_value" })
          create(:archive_reason, :moved_out_of_area, team:, patient:)
        end

        it { should_not include(patient) }
      end
    end

    describe "#appear_in_programmes" do
      subject(:scope) do
        described_class.appear_in_programmes(programmes, academic_year:)
      end

      let(:programmes) { [Programme.td_ipv] }
      let(:academic_year) { AcademicYear.current }

      it { should be_empty }

      context "with a patient in no sessions" do
        before { create(:patient) }

        it { should be_empty }
      end

      context "in a session with the right year group" do
        let(:session) { create(:session, programmes:) }

        let(:patient) { create(:patient, session:, year_group: 9) }

        it { should include(patient) }
      end

      context "in a session but the wrong year group" do
        let(:session) { create(:session, programmes:) }

        let(:patient) { create(:patient, session:, year_group: 8) }

        it { should_not include(patient) }
      end

      context "in a session with the right year group for the programme but not the location" do
        let(:location) { create(:gias_school, :secondary) }
        let(:patient) { create(:patient, session:, year_group: 9) }
        let(:session) { create(:session, location:, programmes:) }

        before do
          programmes.each do |programme|
            create(
              :location_programme_year_group,
              programme:,
              location:,
              year_group: 10
            )
          end
        end

        it { should_not include(patient) }
      end

      context "in multiple sessions with the right year group for one programme" do
        let(:flu_programme) { Programme.flu }
        let(:hpv_programme) { Programme.hpv }

        let(:location) do
          create(:gias_school, programmes: [flu_programme, hpv_programme])
        end
        let(:academic_year) { AcademicYear.current }

        # Year 4 is eligible for flu only.
        let(:patient) { create(:patient, year_group: 4) }

        # Year 9 is eligible for flu and HPV only.
        let(:another_patient) { create(:patient, year_group: 9) }

        before do
          create(:session, location:, programmes: [flu_programme])
          create(:session, location:, programmes: [hpv_programme])

          create(:patient_location, patient:, location:, academic_year:)
          create(
            :patient_location,
            patient: another_patient,
            location:,
            academic_year:
          )
        end

        context "for the right programme" do
          let(:programmes) { [flu_programme] }

          it { should include(patient) }
        end

        context "for the wrong programme" do
          let(:programmes) { [hpv_programme] }

          it { should_not include(patient) }
        end
      end
    end

    describe "#not_appear_in_programmes" do
      subject(:scope) do
        described_class.not_appear_in_programmes(programmes, academic_year:)
      end

      let(:programmes) { [Programme.td_ipv] }
      let(:academic_year) { AcademicYear.current }

      it { should be_empty }

      context "with a patient in no sessions" do
        let(:patient) { create(:patient) }

        it { should include(patient) }
      end

      context "in a session with the right year group" do
        let(:session) { create(:session, programmes:) }

        before { create(:patient, session:, year_group: 9) }

        it { should be_empty }
      end

      context "in a session but the wrong year group" do
        let(:session) { create(:session, programmes:) }

        let(:patient) { create(:patient, session:, year_group: 8) }

        it { should include(patient) }
      end

      context "in a session with the right year group for the programme but not the location" do
        let(:location) { create(:gias_school, :secondary) }
        let(:session) { create(:session, location:, programmes:) }
        let(:patient) { create(:patient, session:, year_group: 9) }

        before do
          programmes.each do |programme|
            create(
              :location_programme_year_group,
              programme:,
              location:,
              year_group: 10
            )
          end
        end

        it { should include(patient) }
      end

      context "in multiple sessions with the right year group for one programme" do
        let(:flu_programme) { Programme.flu }
        let(:hpv_programme) { Programme.hpv }

        let(:location) do
          create(:gias_school, programmes: [flu_programme, hpv_programme])
        end
        let(:academic_year) { AcademicYear.current }

        # Year 4 is eligible for flu only.
        let!(:patient) { create(:patient, year_group: 4) }

        # Year 9 is eligible for flu and HPV only.
        let(:another_patient) { create(:patient, year_group: 9) }

        before do
          create(:session, location:, programmes: [flu_programme])
          create(:session, location:, programmes: [hpv_programme])

          create(:patient_location, patient:, location:, academic_year:)
          create(
            :patient_location,
            patient: another_patient,
            location:,
            academic_year:
          )
        end

        context "for the right programme" do
          let(:programmes) { [flu_programme] }

          it { should be_empty }
        end

        context "for the wrong programme" do
          let(:programmes) { [hpv_programme] }

          it { should include(patient) }
        end
      end
    end

    describe "#search_by_name_or_nhs_number" do
      subject(:scope) { described_class.search_by_name_or_nhs_number(query) }

      let(:patient_a) do
        # exact match comes first
        create(
          :patient,
          given_name: "Neil",
          family_name: "Armstrong",
          nhs_number: "0123456789"
        )
      end
      let(:patient_b) do
        # similar match comes next
        create(:patient, given_name: "Nei", family_name: "Armstro")
      end
      let(:patient_c) do
        # least similar match comes last
        create(:patient, given_name: "Ne", family_name: "Arms")
      end
      let(:patient_d) do
        # no match isn't returned
        create(:patient, given_name: "Buzz", family_name: "Aldrin")
      end

      context "with an NHS number" do
        let(:query) { "0123456789" }

        it "returns the patient with the NHS number" do
          expect(scope).to eq([patient_a])
        end
      end

      context "with an NHS number with whitespace" do
        let(:query) { "012 345 6789 " }

        it "returns the patient with the NHS number" do
          expect(scope).to eq([patient_a])
        end
      end

      context "with full name, in `given_name family_name` format" do
        let(:query) { "Neil Armstrong" }

        it "returns the patients in the correct order" do
          expect(scope).to eq([patient_a, patient_b, patient_c])
        end
      end

      context "with exact name, in `FAMILY_NAME, given_name` format" do
        let(:query) { "ARMSTRONG, Neil" }

        it "returns the patients in the correct order" do
          expect(scope).to eq([patient_a, patient_b, patient_c])
        end
      end

      context "with exact name, in `family_name given_name` format" do
        let(:query) { "Armstrong Neil" }

        it "returns the patients in the correct order" do
          expect(scope).to eq([patient_a, patient_b, patient_c])
        end
      end

      context "with last name only" do
        let(:query) { "Armstrong" }

        it "returns the patients in the correct order" do
          expect(scope).to eq([patient_a, patient_b, patient_c])
        end
      end

      context "with first name only" do
        let(:query) { "Neil" }

        it "returns the patients in the correct order" do
          expect(scope).to eq([patient_a])
        end
      end

      context "with only a small part of the surname" do
        let(:query) { "Arm" }

        it "still finds all three patients" do
          expect(scope).to contain_exactly(patient_c, patient_b, patient_a)
        end
      end

      context "with first name and a small part of the surname" do
        let(:query) { "Neil Arm" }

        it "returns the patients in the correct order" do
          expect(scope).to eq([patient_a, patient_b, patient_c])
        end
      end
    end

    describe "#order_by_name" do
      subject(:scope) { described_class.order_by_name }

      let(:patient_a) { create(:patient, family_name: "Adams") }
      let(:patient_b) do
        create(:patient, given_name: "christine", family_name: "Jones")
      end
      let(:patient_c) do
        create(:patient, given_name: "claire", family_name: "Jones")
      end

      it { should eq([patient_a, patient_b, patient_c]) }
    end

    describe "#consent_given_and_safe_to_vaccinate" do
      subject(:scope) do
        described_class.consent_given_and_safe_to_vaccinate(
          programmes:,
          academic_year:
        )
      end

      let(:programmes) { [Programme.flu, Programme.hpv] }
      let(:session) { create(:session, programmes:) }
      let(:academic_year) { AcademicYear.current }

      it { should be_empty }

      context "with a patient eligible for vaccination" do
        let(:patient) do
          create(:patient, :consent_given_triage_not_needed, session:)
        end

        it { should include(patient) }
      end
    end

    describe "#has_clinic_notification" do
      subject(:scope) do
        described_class.has_clinic_notification(team:, academic_year:)
      end

      let(:team) { create(:team) }
      let(:academic_year) { AcademicYear.current }
      let(:patient_with_notification) { create(:patient) }
      let(:patient_without_notification) { create(:patient) }

      it { should be_empty }

      context "when patient has a clinic notification" do
        before do
          create(
            :clinic_notification,
            :initial_invitation,
            patient: patient_with_notification,
            team:,
            academic_year:,
            programmes: [Programme.flu]
          )
        end

        it { should include(patient_with_notification) }
        it { should_not include(patient_without_notification) }
      end

      context "when patient has a clinic notification for different team" do
        let(:other_team) { create(:team) }

        before do
          create(
            :clinic_notification,
            :initial_invitation,
            patient: patient_with_notification,
            team: other_team,
            academic_year:,
            programmes: [Programme.flu]
          )
        end

        it { should_not include(patient_with_notification) }
      end

      context "when patient has a clinic notification for different academic year" do
        before do
          create(
            :clinic_notification,
            :initial_invitation,
            patient: patient_with_notification,
            team:,
            academic_year: academic_year - 1,
            programmes: [Programme.flu]
          )
        end

        it { should_not include(patient_with_notification) }
      end

      context "when filtering by programmes" do
        subject(:scope) do
          described_class.has_clinic_notification(
            team:,
            academic_year:,
            programmes: [Programme.flu]
          )
        end

        let(:flu_programme) { Programme.flu }
        let(:hpv_programme) { Programme.hpv }

        before do
          create(
            :clinic_notification,
            :initial_invitation,
            patient: patient_with_notification,
            team:,
            academic_year:,
            programmes: [flu_programme]
          )
          create(
            :clinic_notification,
            :initial_invitation,
            patient: patient_without_notification,
            team:,
            academic_year:,
            programmes: [hpv_programme]
          )
        end

        it { should include(patient_with_notification) }
        it { should_not include(patient_without_notification) }
      end
    end
  end

  describe "validations" do
    context "with an invalid GP practice" do
      subject(:patient) { build(:patient, gp_practice: create(:gias_school)) }

      it "is invalid" do
        expect(patient).not_to be_valid
        expect(patient.errors[:gp_practice]).to include(
          "must be a GP practice location type"
        )
      end
    end

    context "with an invalid school" do
      subject(:patient) { build(:patient, school: create(:community_clinic)) }

      it "is invalid" do
        expect(patient).not_to be_valid
        expect(patient.errors[:school]).to include(
          "must be a school location type"
        )
      end
    end
  end

  describe "normalizations" do
    let(:patient) { described_class.new }

    it do
      expect(patient).to normalize(:nhs_number).from(
        "012\u200D345\u200D6789"
      ).to("0123456789")
    end

    it { should normalize(:nhs_number).from(" 0123456789 ").to("0123456789") }

    it { should normalize(:address_postcode).from(" SW111AA ").to("SW11 1AA") }
  end

  describe "#teams" do
    subject(:teams) { patient.teams }

    let(:patient) { create(:patient) }

    it { should be_empty }

    context "when a team exists" do
      let!(:team) { create(:team) }

      it { should be_empty }

      context "and the patient belongs to the team" do
        let(:session) { create(:session, team:) }
        let(:patient) { create(:patient, session:) }

        it { should include(team) }
      end

      context "and the patient belongs to multiple sessions under the same team" do
        let(:menacwy_session) do
          create(:session, team:, programmes: [Programme.menacwy])
        end
        let(:td_ipv_session) do
          create(:session, team:, programmes: [Programme.td_ipv])
        end
        let(:patient) { create(:patient, session: menacwy_session) }

        before { create(:patient_location, patient:, session: td_ipv_session) }

        it { should contain_exactly(team) }
      end
    end
  end

  describe "#archived?" do
    let(:patient) { create(:patient) }
    let(:team) { create(:team) }

    shared_examples "archived? behavior" do
      context "without an archive reason" do
        it { should be(false) }
      end

      context "with an archive reason for the team" do
        before { create(:archive_reason, :moved_out_of_area, team:, patient:) }

        it { should be(true) }
      end

      context "with an archive reason for a different team" do
        before { create(:archive_reason, :imported_in_error, patient:) }

        it { should be(false) }
      end
    end

    context "without preloading" do
      subject(:archived?) { patient.archived?(team:) }

      include_examples "archived? behavior"
    end

    context "with preloading" do
      subject(:archived?) do
        described_class
          .includes(:archive_reasons)
          .find(patient.id)
          .archived?(team:)
      end

      include_examples "archived? behavior"
    end
  end

  describe "#not_archived?" do
    subject(:not_archived?) { patient.not_archived?(team:) }

    let(:patient) { create(:patient) }
    let(:team) { create(:team) }

    context "without an archive reason" do
      it { should be(true) }
    end

    context "with an archive reason for the team" do
      before { create(:archive_reason, :moved_out_of_area, team:, patient:) }

      it { should be(false) }
    end

    context "with an archive reason for a different team" do
      before { create(:archive_reason, :imported_in_error, patient:) }

      it { should be(true) }
    end
  end

  describe "#not_in_team?" do
    let(:patient) { create(:patient) }
    let(:team) { create(:team) }
    let(:academic_year) { 2025 }
    let(:school) { create(:gias_school, team:) }

    shared_examples "not_in_team? behavior" do
      context "when the patient is in the team" do
        before { SchoolMove.new(patient:, school:, academic_year:).confirm! }

        it { should be(false) }
      end

      context "when the patient is not in the team" do
        it { should be(true) }
      end

      context "when the patient is in the team for a different academic year" do
        before do
          SchoolMove.new(patient:, school:, academic_year: 2024).confirm!
        end

        it { should be(true) }
      end

      context "when the patient is in a different team" do
        let(:other_team) { create(:team) }
        let(:other_school) { create(:gias_school, team: other_team) }

        before do
          SchoolMove.new(
            patient:,
            school: other_school,
            academic_year:
          ).confirm!
        end

        it { should be(true) }
      end
    end

    context "without preloading" do
      subject(:not_in_team?) { patient.not_in_team?(team:, academic_year:) }

      include_examples "not_in_team? behavior"
    end

    context "with preloading" do
      subject(:not_in_team?) do
        described_class
          .includes(patient_locations: { location: :team_locations })
          .find(patient.id)
          .not_in_team?(team:, academic_year:)
      end

      include_examples "not_in_team? behavior"
    end
  end

  describe "#show_year_group?" do
    subject { patient.show_year_group?(team:) }

    let(:programmes) { [Programme.flu, Programme.hpv] }
    let(:team) { create(:team, programmes:) }
    let(:school) { create(:gias_school, team:) }

    context "outside the preparation period" do
      around { |example| travel_to(Date.new(2025, 7, 31)) { example.run } }

      context "for a year 1" do
        let(:patient) { create(:patient, school:, year_group: 1) }

        it { should be(true) }
      end

      context "for a year 7" do
        let(:patient) { create(:patient, school:, year_group: 7) }

        it { should be(true) }
      end

      context "for a year 11" do
        let(:patient) { create(:patient, school:, year_group: 11) }

        it { should be(true) }
      end

      context "for a year 12" do
        let(:patient) { create(:patient, school:, year_group: 12) }

        it { should be(false) }
      end
    end

    context "inside the preparation period" do
      around { |example| travel_to(Date.new(2025, 8, 1)) { example.run } }

      context "for a year 1" do
        let(:patient) { create(:patient, school:, year_group: 1) }

        it { should be(true) }
      end

      context "for a year 7" do
        let(:patient) { create(:patient, school:, year_group: 7) }

        it { should be(true) }
      end

      context "for a year 11" do
        let(:patient) { create(:patient, school:, year_group: 11) }

        it { should be(false) }
      end

      context "for a year 12" do
        let(:patient) { create(:patient, school:, year_group: 12) }

        it { should be(false) }
      end
    end

    context "when the team has national reporting access" do
      let(:patient) { create(:patient, school:, year_group: 1) }
      let(:team) { create(:team, :national_reporting) }

      it { should be(false) }
    end
  end

  describe "#initials" do
    subject { patient.initials }

    let(:patient) { create(:patient, given_name: "John", family_name: "Doe") }

    it { should eq("JD") }
  end

  describe "#can_self_consent_after_gillick_assessment?" do
    subject(:can_self_consent_after_gillick_assessment) do
      patient.can_self_consent_after_gillick_assessment?(
        session:,
        programme_type: programme.type
      )
    end

    let(:programme) { Programme.sample }
    let(:session) { create(:session, programmes: [programme]) }
    let(:patient) { create(:patient) }

    context "when patient has no Gillick assessments" do
      it { should be(false) }
    end

    context "when patient has a Gillick assessment for a different programme" do
      before do
        create(
          :gillick_assessment,
          :competent,
          patient:,
          programme_type: "hpv",
          session:
        )
      end

      let(:programme) { Programme.flu }

      it { should be(false) }
    end

    context "when patient has a Gillick assessment for a different session" do
      let(:other_session) { create(:session, programmes: [programme]) }

      before do
        create(
          :gillick_assessment,
          :competent,
          patient:,
          programme_type: programme.type,
          session: other_session
        )
      end

      it { should be(false) }
    end

    context "when patient has a not competent Gillick assessment" do
      before do
        create(
          :gillick_assessment,
          :not_competent,
          patient:,
          programme_type: programme.type,
          session:
        )
      end

      it { should be(false) }
    end

    context "when patient has a competent Gillick assessment" do
      before do
        create(
          :gillick_assessment,
          :competent,
          patient:,
          programme_type: programme.type,
          session:
        )
      end

      it { should be(true) }
    end

    context "when patient has multiple Gillick assessments" do
      before do
        create(
          :gillick_assessment,
          :not_competent,
          patient:,
          programme_type: programme.type,
          session:
        )
        create(
          :gillick_assessment,
          :competent,
          patient:,
          programme_type: programme.type,
          session:
        )
      end

      it "returns the result of the most recent assessment" do
        expect(can_self_consent_after_gillick_assessment).to be(true)
      end
    end
  end

  describe "#has_patient_specific_direction?" do
    subject { patient.has_patient_specific_direction?(team:) }

    let(:team) { create(:team) }
    let(:patient) { create(:patient) }

    it { should be(false) }

    context "with a PSD from the same team" do
      before { create(:patient_specific_direction, patient:, team:) }

      it { should be(true) }
    end

    context "with a PSD from a different team" do
      before { create(:patient_specific_direction, patient:) }

      it { should be(false) }
    end
  end

  describe "#vaccine_criteria" do
    subject(:vaccine_criteria) do
      patient.vaccine_criteria(programme:, academic_year:)
    end

    let(:patient) { create(:patient) }
    let(:programme) { Programme.sample }
    let(:academic_year) { AcademicYear.current }

    describe "#vaccine_methods" do
      subject { vaccine_criteria.vaccine_methods }

      it { should be_empty }

      context "when consent given and triage not required" do
        before do
          create(
            :patient_programme_status,
            :due,
            patient:,
            programme:,
            vaccine_methods: %w[nasal injection]
          )
        end

        it { should eq(%w[nasal injection]) }
      end
    end
  end

  describe "#update_from_pds!" do
    subject(:update_from_pds!) { patient.update_from_pds!(pds_patient) }

    let(:patient) { create(:patient, nhs_number: "0123456789") }
    let(:pds_patient) { PDS::Patient.new(nhs_number: "0123456789") }

    it "doesn't set a date of death" do
      expect { update_from_pds! }.not_to change(patient, :date_of_death)
    end

    it "doesn't flag as restricted" do
      expect { update_from_pds! }.not_to change(patient, :restricted_at)
    end

    it "doesn't change the GP practice" do
      expect { update_from_pds! }.not_to change(patient, :gp_practice)
    end

    it "sets the updated from PDS date and time" do
      freeze_time do
        expect { update_from_pds! }.to change(
          patient,
          :updated_from_pds_at
        ).from(nil).to(Time.current)
      end
    end

    context "when the NHS number doesn't match" do
      let(:pds_patient) { PDS::Patient.new(nhs_number: "abc") }

      it "raises an error" do
        expect { update_from_pds! }.to raise_error(Patient::NHSNumberMismatch)
      end
    end

    context "with notification of death" do
      let(:pds_patient) do
        PDS::Patient.new(
          nhs_number: "0123456789",
          date_of_death: Date.new(2024, 1, 1)
        )
      end

      it "sets the date of death" do
        expect { update_from_pds! }.to change(patient, :date_of_death).to(
          Date.new(2024, 1, 1)
        )
      end

      it "sets the date of death recorded at" do
        freeze_time do
          expect { update_from_pds! }.to change(
            patient,
            :date_of_death_recorded_at
          ).from(nil).to(Time.current)
        end
      end

      context "when in an upcoming session" do
        let(:session) do
          create(
            :session,
            academic_year: AcademicYear.pending,
            date: AcademicYear.pending.to_academic_year_date_range.begin
          )
        end

        let!(:patient_location) do
          create(:patient_location, patient:, session:)
        end

        it "sets the range of the patient location" do
          expect(patient_location.date_range).to eq(
            -Float::INFINITY...Float::INFINITY
          )
          expect(patient.patient_locations).to include(patient_location)

          expect { update_from_pds! }.not_to change(PatientLocation, :count)

          expect(patient_location.reload.date_range).to eq(
            -Float::INFINITY...Date.tomorrow
          )
        end

        it "archives the patient" do
          expect { update_from_pds! }.to change(
            patient.archive_reasons,
            :count
          ).from(0).to(1)

          archive_reason = patient.archive_reasons.first
          expect(archive_reason).to be_deceased
          expect(archive_reason.team_id).to eq(session.team_id)
        end

        context "when already archived" do
          let!(:archive_reason) do
            create(
              :archive_reason,
              :moved_out_of_area,
              patient:,
              team: session.team
            )
          end

          it "updates the existing archive reason" do
            expect(archive_reason).to be_moved_out_of_area
            expect { update_from_pds! }.not_to change(ArchiveReason, :count)
            expect(archive_reason.reload).to be_deceased
          end
        end
      end
    end

    context "with a restricted flag" do
      let(:pds_patient) do
        PDS::Patient.new(nhs_number: "0123456789", restricted: true)
      end

      it "sets restricted at" do
        freeze_time do
          expect { update_from_pds! }.to change(patient, :restricted_at).from(
            nil
          ).to(Time.current)
        end
      end
    end

    context "with a GP practice ODS code" do
      let(:gp_practice) { create(:gp_practice) }

      let(:pds_patient) do
        PDS::Patient.new(
          nhs_number: "0123456789",
          gp_ods_code: gp_practice.ods_code
        )
      end

      it "sets the GP practice" do
        expect { update_from_pds! }.to change(patient, :gp_practice).from(
          nil
        ).to(gp_practice)
      end
    end

    context "with a GP practice that doesn't exist" do
      let(:pds_patient) do
        PDS::Patient.new(nhs_number: "0123456789", gp_ods_code: "GP")
      end

      it "records an error in Sentry" do
        expect(Sentry).to receive(:capture_exception).with(
          an_instance_of(Patient::UnknownGPPractice)
        )
        update_from_pds!
      end
    end

    context "when the patient is currently invalidated" do
      let(:patient) do
        create(:patient, :invalidated, school:, nhs_number: "0123456789")
      end

      let(:programme) { Programme.sample }
      let(:team) { create(:team, programmes: [programme]) }
      let(:school) { create(:gias_school, team:) }
      let(:session) { create(:session, location: school, team:, programme:) }

      it "marks the patient as not invalidated" do
        expect { update_from_pds! }.to change(patient, :invalidated?).from(
          true
        ).to(false)
      end
    end
  end

  describe "#invalidate!" do
    subject(:invalidate!) { patient.invalidate! }

    let(:patient) { create(:patient) }

    it "marks the patient as invalidated" do
      expect { invalidate! }.to change(patient, :invalidated?).from(false).to(
        true
      )
    end

    it "sets the date/time of when the patient was invalidated" do
      freeze_time do
        expect { invalidate! }.to change(patient, :invalidated_at).from(nil).to(
          Time.current
        )
      end
    end
  end

  describe "#should_sync_vaccinations_to_nhs_immunisations_api" do
    subject(:should_sync_vaccinations_to_nhs_immunisations_api?) do
      patient.send(:should_sync_vaccinations_to_nhs_immunisations_api?)
    end

    let(:patient) { create(:patient, nhs_number: "9449310475") }
    let(:programme) { Programme.hpv }
    let(:session) { create(:session, programmes: [programme]) }
    let(:vaccination_record) do
      create(:vaccination_record, patient:, programme:, session:)
    end

    context "when nhs_number changes" do
      it "syncs vaccination records to NHS Immunisations API" do
        patient.update!(nhs_number: "9449304130")

        expect(should_sync_vaccinations_to_nhs_immunisations_api?).to be_truthy
      end
    end

    context "when invalidated_at changes" do
      it "syncs vaccination records to NHS Immunisations API" do
        patient.update!(invalidated_at: Time.current)

        expect(should_sync_vaccinations_to_nhs_immunisations_api?).to be_truthy
      end
    end

    context "when other attributes change" do
      it "does not sync vaccination records to NHS Immunisations API" do
        patient.update!(given_name: "NewName")

        expect(should_sync_vaccinations_to_nhs_immunisations_api?).to be_falsy
      end
    end
  end

  describe "#should_search_vaccinations_from_nhs_immunisations_api?" do
    subject(:should_search_vaccinations_from_nhs_immunisations_api?) do
      patient.send(:should_search_vaccinations_from_nhs_immunisations_api?)
    end

    let(:patient) { create(:patient, nhs_number: "9449310475") }

    context "when nhs_number changes" do
      it "syncs vaccination records to NHS Immunisations API" do
        patient.update!(nhs_number: "9449304130")

        expect(
          should_search_vaccinations_from_nhs_immunisations_api?
        ).to be_truthy
      end
    end

    context "when other attributes change" do
      it "does not sync vaccination records to NHS Immunisations API" do
        patient.update!(given_name: "NewName")

        expect(
          should_search_vaccinations_from_nhs_immunisations_api?
        ).to be_falsy
      end
    end
  end

  describe "#stage_changes" do
    let(:patient) { create(:patient, given_name: "John", family_name: "Doe") }

    it "stages new changes in pending_changes" do
      patient.stage_changes(given_name: "Jane", address_line_1: "123 New St")

      expect(patient.pending_changes).to eq(
        { "given_name" => "Jane", "address_line_1" => "123 New St" }
      )
    end

    it "does not stage unchanged attributes" do
      patient.stage_changes(given_name: "John", family_name: "Smith")

      expect(patient.pending_changes).to eq({ "family_name" => "Smith" })
    end

    it "does not update other attributes directly" do
      patient.stage_changes(given_name: "Jane", family_name: "Smith")

      expect(patient.given_name).to eq("John")
      expect(patient.family_name).to eq("Doe")
    end

    it "does not save any changes if no valid changes are provided" do
      expect { patient.stage_changes(given_name: "John") }.not_to(
        change { patient.reload.pending_changes }
      )
    end
  end

  describe "#with_pending_changes" do
    let(:patient) { create(:patient) }

    it "returns the patient with pending changes applied" do
      patient.stage_changes(given_name: "Jane")
      expect(patient.given_name_changed?).to be(false)

      changed_patient = patient.with_pending_changes
      expect(changed_patient.given_name_changed?).to be(true)
      expect(changed_patient.family_name_changed?).to be(false)
      expect(changed_patient.given_name).to eq("Jane")
    end
  end

  describe "#dup_for_pending_changes" do
    subject(:new_patient) { old_patient.dup_for_pending_changes }

    let(:old_patient) { create(:patient) }

    it { should be_valid }

    it "doesn't change the old patient" do
      new_patient
      expect(old_patient).not_to be_changed
    end

    it "clears the NHS number" do
      expect(new_patient.nhs_number).to be_nil
    end

    context "when the old patient has upcoming sessions" do
      let(:team) { create(:team) }
      let(:location) { create(:gias_school, team:) }

      before do
        create(
          :patient_location,
          patient: old_patient,
          location:,
          academic_year: AcademicYear.pending
        )
      end

      it "adds the new patient to any upcoming sessions" do
        expect(new_patient.patient_locations.size).to eq(1)
        expect(new_patient.patient_locations.first.location_id).to eq(
          location.id
        )
      end

      it "adds the new patient to the teams" do
        expect(new_patient.patient_teams.size).to eq(1)
        expect(new_patient.patient_teams.first.team_id).to eq(team.id)
        expect(new_patient.patient_teams.first.sources).to contain_exactly(
          "patient_location"
        )
      end
    end

    context "when the old patient has school moves" do
      let(:team) { create(:team) }
      let(:school) { create(:gias_school, team:) }

      before { create(:school_move, :to_school, patient: old_patient, school:) }

      it "adds any school moves from the old patient" do
        expect(new_patient.school_moves.size).to eq(1)
        expect(new_patient.school_moves.first.school).to eq(school)
      end

      it "adds the new patient to the teams" do
        expect(new_patient.patient_teams.size).to eq(1)
        expect(new_patient.patient_teams.first.team_id).to eq(team.id)
        expect(new_patient.patient_teams.first.sources).to contain_exactly(
          "school_move_school"
        )
      end
    end
  end

  describe "#destroy_childless_parents" do
    context "when parent has only one child" do
      let(:parent) { create(:parent) }
      let!(:patient) { create(:patient, parents: [parent]) }

      it "destroys the parent when the patient is destroyed" do
        expect { patient.destroy }.to change(Parent, :count).by(-1)
      end
    end

    context "when parent has multiple children" do
      let(:parent) { create(:parent) }
      let!(:patient) { create(:patient, parents: [parent]) }

      before { create(:patient, parents: [parent]) }

      it "does not destroy the parent when one patient is destroyed" do
        expect { patient.destroy }.not_to change(Parent, :count)
      end
    end

    context "when patient has multiple parents" do
      let!(:patient) { create(:patient, parents: create_list(:parent, 2)) }

      it "destroys only the childless parents" do
        expect { patient.destroy }.to change(Parent, :count).by(-2)
      end
    end
  end

  describe "#latest_pds_search_result" do
    subject(:latest_pds_search_result) { patient.latest_pds_search_result }

    let(:patient) { create(:patient) }

    context "with no PDS search results" do
      it { should be_nil }
    end

    context "with unique NHS number in PDS search results" do
      let(:import) { create(:class_import) }

      before do
        create(
          :patient_changeset,
          patient:,
          import:,
          pds_nhs_number: "9449304130"
        )
        create(:pds_search_result, patient:, import:, nhs_number: "9449304130")
        create(
          :pds_search_result,
          patient:,
          import:,
          nhs_number: nil,
          step: :no_fuzzy_with_wildcard_family_name
        )
      end

      it { should eq("9449304130") }
    end

    context "with conflicting NHS numbers in PDS search results" do
      before do
        create(:pds_search_result, patient:, nhs_number: "9449304130")
        create(
          :pds_search_result,
          patient:,
          nhs_number: "9449310475",
          step: :no_fuzzy_with_wildcard_family_name
        )
      end

      it { should be_nil }
    end
  end

  describe "#pds_lookup_match?" do
    subject(:pds_lookup_match?) { patient.pds_lookup_match? }

    let(:patient) { create(:patient, nhs_number: "9449304130") }

    context "when patient has no NHS number" do
      let(:patient) { create(:patient, nhs_number: nil) }

      it { should be(false) }
    end

    context "with no PDS search results" do
      it { should be(false) }
    end

    context "with matching PDS search result" do
      let(:import) { create(:class_import) }

      before do
        create(
          :patient_changeset,
          patient:,
          import:,
          pds_nhs_number: "9449304130"
        )
        create(:pds_search_result, patient:, import:, nhs_number: "9449304130")
      end

      it { should be(true) }
    end

    context "with non-matching PDS search result" do
      let(:import) { create(:class_import) }

      before do
        create(
          :patient_changeset,
          patient:,
          import:,
          pds_nhs_number: "9449310475"
        )
        create(:pds_search_result, patient:, import:)
      end

      it { should be(false) }
    end
  end
end
