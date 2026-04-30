# frozen_string_literal: true

# == Schema Information
#
# Table name: patient_changesets
#
#  id                    :bigint           not null, primary key
#  data                  :jsonb
#  import_type           :string           not null
#  matched_on_nhs_number :boolean
#  pds_nhs_number        :string
#  processed_at          :datetime
#  record_type           :integer          default("new_patient"), not null
#  row_number            :integer
#  status                :integer          default("pending"), not null
#  uploaded_nhs_number   :string
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  import_id             :bigint           not null
#  patient_id            :bigint
#  school_id             :bigint
#
# Indexes
#
#  index_patient_changesets_on_import      (import_type,import_id)
#  index_patient_changesets_on_patient_id  (patient_id)
#  index_patient_changesets_on_status      (status)
#
# Foreign Keys
#
#  fk_rails_...  (patient_id => patients.id)
#  fk_rails_...  (school_id => locations.id)
#
describe PatientChangeset do
  subject(:changeset) do
    described_class.create_from_import_row(
      row: import_row,
      import: create(:class_import, team:),
      row_number: 1
    )
  end

  let(:team) { create(:team) }
  let(:school) { create(:gias_school, urn: "123456", team:) }

  let(:valid_data) do
    {
      child_school_urn: "123456",
      child_first_name: "Jimmy",
      child_last_name: "Smith",
      child_date_of_birth: "2010-01-01",
      child_address_line_1: "10 Downing Street",
      child_postcode: "SW1A 1AA",
      child_nhs_number: "999 000 0026",
      parent_1_email: "john@example.com",
      parent_1_phone: "07412345678"
    }
  end

  let(:import_row) do
    instance_double(
      CohortImportRow,
      school:,
      import_attributes:,
      parent_1_import_attributes:,
      parent_2_import_attributes:,
      academic_year: AcademicYear.current,
      school_move_source: "import"
    )
  end

  let(:import_attributes) do
    {
      address_line_1: valid_data[:child_address_line_1],
      address_postcode: valid_data[:child_postcode],
      date_of_birth: Date.parse(valid_data[:child_date_of_birth]),
      family_name: valid_data[:child_last_name],
      given_name: valid_data[:child_first_name],
      nhs_number: valid_data[:child_nhs_number]&.gsub(/\s/, "")
    }.compact
  end

  let(:parent_1_import_attributes) do
    {
      full_name: "John Smith",
      relationship: "Father",
      email: "john@example.com",
      phone: "07412345678"
    }
  end

  let(:parent_2_import_attributes) { {} }

  describe "#patient" do
    subject(:patient) { changeset.patient }

    it do
      expect(patient).to have_attributes(
        given_name: "Jimmy",
        family_name: "Smith",
        date_of_birth: Date.new(2010, 1, 1),
        nhs_number: "9990000026",
        address_line_1: "10 Downing Street",
        address_postcode: "SW1A 1AA"
      )
    end

    context "with existing patient" do
      let!(:existing_patient) do
        create(:patient, nhs_number: "9990000026", given_name: "James")
      end

      it { should eq(existing_patient) }
      it { should have_attributes(given_name: "James") }
    end
  end

  describe "#parents" do
    subject(:parents) { changeset.parents }

    it "builds parent" do
      expect(parents.sole).to have_attributes(
        full_name: "John Smith",
        email: "john@example.com"
      )
    end
  end

  describe "#parent_relationships" do
    subject(:parent_relationships) { changeset.parent_relationships }

    it "creates a relationship for the parent" do
      expect(parent_relationships.sole).to have_attributes(type: "father")
      expect(parent_relationships.sole.parent).to eq changeset.parents.sole
      expect(parent_relationships.sole.patient).to eq changeset.patient
    end
  end

  describe "#school_move" do
    subject(:school_move) { changeset.school_move }

    context "with school change" do
      before do
        create(:patient, nhs_number: "9990000026", school: create(:gias_school))
      end

      it "creates school move record" do
        expect(school_move.school.urn).to eq("123456")
      end
    end
  end

  describe "#school_move_to_unknown_school_from_another_team?" do
    subject(:is_school_move_to_unknown_school_from_another_team?) do
      changeset.school_move_to_unknown_school_from_another_team?
    end

    let(:another_team) { create(:team, name: "Another Team") }
    let(:school_in_other_team) do
      create(:gias_school, name: "School in another team", team: another_team)
    end

    context "when new location is a known school" do
      let(:school) { create(:gias_school) }

      before do
        create(:patient, nhs_number: "9990000026", school: school_in_other_team)
      end

      it { should be false }
    end

    context "when new location is home educated" do
      let(:school) { team.home_educated_school }

      before do
        create(:patient, nhs_number: "9990000026", school: school_in_other_team)
      end

      it { should be false }
    end

    context "when new location is unknown school" do
      let(:school) { team.unknown_school }

      context "patient is in a school in another team" do
        before do
          create(
            :patient,
            nhs_number: "9990000026",
            school: school_in_other_team
          )
        end

        it { should be true }
      end

      context "patient is in unknown school in another team" do
        before do
          create(
            :patient,
            nhs_number: "9990000026",
            school: another_team.unknown_school
          )
        end

        it { should be false }
      end

      context "patient is home educated in another team" do
        before do
          create(
            :patient,
            nhs_number: "9990000026",
            school: another_team.home_educated_school
          )
        end

        it { should be true }
      end
    end
  end
end
