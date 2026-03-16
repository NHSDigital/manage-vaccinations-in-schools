# frozen_string_literal: true

describe AppImportReviewComponent do
  subject(:rendered) { render_inline(component) }

  let(:component) do
    described_class.new(
      import:,
      inter_team:,
      new_records: [new_records_pagy, new_records],
      auto_matched_records: [auto_matched_records_pagy, auto_matched_records],
      import_issues: [import_issues_pagy, import_issues],
      school_moves: [school_moves_pagy, school_moves],
      skipped_school_moves:,
      open_sections:
    )
  end

  let(:team) { create(:team) }
  let(:user) { create(:user, team:) }
  let(:location) { create(:school, team:, name: "Test School") }
  let(:second_location) { create(:school, team:, name: "Second Test School") }
  let(:other_team) { create(:team) }
  let(:other_location) do
    create(:school, team: other_team, name: "Other Test School")
  end

  let(:import) { create(:cohort_import, team:, uploaded_by: user) }

  let(:new_patient) { create(:patient, school: location) }
  let(:auto_matched_patient) { create(:patient, school: location) }
  let(:import_issue_patient) { create(:patient, school: location) }
  let(:inter_team_patient) { create(:patient, school: other_location) }
  let(:school_move_patient) { create(:patient, school: second_location) }
  let(:second_school_move_patient) { create(:patient, school: second_location) }

  let(:new_records) { [] }
  let(:new_records_pagy) do
    instance_double(Pagy, count: 0, limit: 50).as_null_object
  end
  let(:auto_matched_records) { [] }
  let(:auto_matched_records_pagy) do
    instance_double(Pagy, count: 0, limit: 50).as_null_object
  end
  let(:import_issues) { [] }
  let(:import_issues_pagy) do
    instance_double(Pagy, count: 0, limit: 50).as_null_object
  end
  let(:inter_team) { [] }
  let(:school_moves) { [] }
  let(:school_moves_pagy) do
    instance_double(Pagy, count: 0, limit: 50).as_null_object
  end
  let(:skipped_school_moves) { [] }
  let(:open_sections) { [] }

  shared_examples "section with details" do |title:, summary:, count:|
    it "renders section '#{title}'" do
      expect(rendered).to have_css("h2.nhsuk-heading-m", text: title)
      expect(rendered).to have_css(
        ".nhsuk-details__summary-text",
        text: summary
      )
    end

    it "has #{count} record(s) in the section" do
      expect(rendered).to have_css("h2", text: title)
      expect(rendered).to have_css(".nhsuk-details")
      expect(rendered).to have_css(
        ".nhsuk-table__body .nhsuk-table__row",
        count: count,
        visible: :hidden
      )
    end
  end

  describe "with new records" do
    let(:new_records_pagy) do
      instance_double(Pagy, count: 2, limit: 50).as_null_object
    end
    let(:new_records) do
      [
        create(:patient_changeset, :new_patient, import:, patient: new_patient),
        create(:patient_changeset, :new_patient, import:)
      ]
    end

    before do
      allow(AppPaginationComponent).to receive(:new) { double.as_null_object }
    end

    include_examples "section with details",
                     title: "New records",
                     summary: "2 new records",
                     count: 2

    it "shows the section description" do
      expect(rendered).to have_content(
        "This upload includes 2 new records that are not currently in Mavis"
      )
      expect(rendered).to have_content(
        "If you approve the upload, these records will be added to Mavis"
      )
    end
  end

  describe "with auto-matched records" do
    let(:auto_matched_records_pagy) do
      instance_double(Pagy, count: 3, limit: 50).as_null_object
    end
    let(:auto_matched_records) do
      [
        create(
          :patient_changeset,
          :auto_match,
          import:,
          patient: auto_matched_patient
        ),
        create(:patient_changeset, :auto_match, import:),
        create(:patient_changeset, :auto_match, import:)
      ]
    end

    before do
      allow(AppPaginationComponent).to receive(:new) { double.as_null_object }
    end

    include_examples "section with details",
                     title: "Records already in Mavis",
                     summary: "3 records already in Mavis",
                     count: 3

    it "shows the section description" do
      expect(rendered).to have_content(
        "This upload includes 3 records that already exist in Mavis"
      )
      expect(rendered).to have_content(
        "If you approve the upload, any additional information will be added to the existing records"
      )
    end
  end

  describe "with inter-team moves" do
    let(:patient) { create(:patient, school: other_location) }
    let(:inter_team) do
      [
        create(
          :patient_changeset,
          :with_school_move,
          import:,
          patient: inter_team_patient,
          school: location
        )
      ]
    end

    before do
      create(
        :patient_location,
        patient: inter_team_patient,
        location: other_location
      )
    end

    include_examples "section with details",
                     title:
                       "Children moving from another SAIS team's area - resolve after import",
                     summary: "1 school move across teams",
                     count: 1

    it "shows the section description" do
      expect(rendered).to have_content(
        "This upload includes child who is currently registered with another team"
      )
      expect(rendered).to have_content(
        "If you approve the upload, you will need to resolve this record in the School moves area of Mavis."
      )
    end
  end

  describe "with inter-team import issues" do
    let(:patient) { create(:patient, school: other_location) }
    let(:inter_team) do
      [
        create(
          :patient_changeset,
          :with_school_move,
          :import_issue,
          import:,
          patient: inter_team_patient,
          school: location
        )
      ]
    end

    before do
      create(
        :patient_location,
        patient: inter_team_patient,
        location: other_location
      )
    end

    it "renders separate expander for close matches" do
      expect(rendered).to have_css(
        ".nhsuk-details__summary-text",
        text: "1 close match to existing records"
      )
    end
  end

  describe "with import issues" do
    let(:import_issues) do
      [
        create(
          :patient_changeset,
          :import_issue,
          import:,
          patient: import_issue_patient
        ),
        create(:patient_changeset, :import_issue, import:)
      ]
    end

    include_examples "section with details",
                     title:
                       "Close matches to existing records - resolve after import",
                     summary: "2 close matches to existing records",
                     count: 2

    it "shows the section description" do
      expect(rendered).to have_content(
        "This upload includes 2 records that are close matches to existing records in Mavis"
      )
      expect(rendered).to have_content(
        "If you approve the upload, you will need to resolve these records in the Issues tab."
      )
    end
  end

  describe "with school moves" do
    let(:school_moves) do
      [
        create(
          :patient_changeset,
          :with_school_move,
          import:,
          patient: school_move_patient,
          school: second_location
        ),
        create(
          :patient_changeset,
          :with_school_move,
          import:,
          patient: second_school_move_patient,
          school: location
        )
      ]
    end

    include_examples "section with details",
                     title: "School moves - resolve after import",
                     summary: "2 school moves",
                     count: 2

    context "for cohort import" do
      it "shows cohort import message" do
        expect(rendered).to have_content(
          "This upload includes 2 children with a different school to the one on their Mavis record"
        )
      end
    end

    context "for class import" do
      let(:import) { create(:class_import, team:, uploaded_by: user) }

      it "shows class import message" do
        expect(rendered).to have_content(
          "This upload will change the school of the children listed below"
        )
        expect(rendered).to have_content(
          "Children present in the class list will be moved into the school"
        )
      end
    end
  end

  describe "with skipped school moves" do
    let(:other_team_school) do
      create(:school, team: other_team, name: "School in Other Team")
    end
    let(:skipped_patient) do
      create(:patient, school: other_team_school, team: other_team)
    end
    let(:skipped_school_moves) do
      [
        create(
          :patient_changeset,
          import:,
          patient: skipped_patient,
          school: nil
        )
      ]
    end

    before do
      skipped_school_moves.first.data["upload"]["home_educated"] = false
      skipped_school_moves.first.save!

      create(
        :patient_location,
        patient: skipped_patient,
        location: other_team_school
      )
    end

    include_examples "section with details",
                     title:
                       "Records not imported - children at schools in other team areas",
                     summary: "1 record not imported",
                     count: 1

    it "shows the section description" do
      expect(rendered).to have_content(
        "1 child is already registered at a school in another team's area"
      )
      expect(rendered).to have_content(
        "This child remains at their current school."
      )
    end
  end

  describe "buttons" do
    context "with records to import" do
      let(:new_records_pagy) do
        instance_double(Pagy, count: 1, limit: 50).as_null_object
      end
      let(:new_records) do
        [
          create(
            :patient_changeset,
            :new_patient,
            import:,
            patient: new_patient
          )
        ]
      end

      before do
        allow(AppPaginationComponent).to receive(:new) { double.as_null_object }
      end

      it "shows approve button" do
        expect(rendered).to have_button("Approve and import records")
      end

      it "shows cancel button" do
        expect(rendered).to have_button("Cancel and delete upload")
      end
    end

    context "with only school moves not from file" do
      let(:school_moves) do
        [
          create(
            :patient_changeset,
            :with_school_move,
            import:,
            patient: school_move_patient,
            school: second_location,
            row_number: nil
          )
        ]
      end

      it "does not show cancel button" do
        expect(rendered).not_to have_button("Cancel and delete upload")
      end
    end

    context "with re-review import" do
      before do
        import.update!(status: :in_re_review)
        allow(AppPaginationComponent).to receive(:new) { double.as_null_object }
      end

      let(:new_records_pagy) do
        instance_double(Pagy, count: 1, limit: 50).as_null_object
      end
      let(:new_records) do
        [
          create(
            :patient_changeset,
            :new_patient,
            import:,
            patient: new_patient
          )
        ]
      end

      it "shows re-review button text" do
        expect(rendered).to have_button("Approve and import changed records")
        expect(rendered).to have_button("Ignore changes")
      end
    end
  end

  describe "section break" do
    it "renders horizontal rule before buttons" do
      expect(rendered).to have_css(
        "hr.nhsuk-section-break.nhsuk-section-break--visible"
      )
    end
  end

  describe "empty sections" do
    let(:new_records_pagy) do
      instance_double(Pagy, count: 0, limit: 50).as_null_object
    end

    it "does not render sections with no records" do
      expect(rendered).not_to have_css("h2", text: "New records")
      expect(rendered).not_to have_css("h2", text: "Records already in Mavis")
    end
  end

  describe "sticky summary" do
    let(:new_records_pagy) do
      instance_double(Pagy, count: 1, limit: 50).as_null_object
    end
    let(:new_records) do
      [create(:patient_changeset, :new_patient, import:, patient: new_patient)]
    end

    before do
      allow(AppPaginationComponent).to receive(:new) { double.as_null_object }
    end

    it "adds sticky module to summary" do
      expect(rendered).to have_css('summary[data-module="app-sticky"]')
    end
  end

  describe "open_sections" do
    let(:new_records_pagy) do
      instance_double(Pagy, count: 1, limit: 50).as_null_object
    end
    let(:new_records) do
      [create(:patient_changeset, :new_patient, import:, patient: new_patient)]
    end

    before do
      allow(AppPaginationComponent).to receive(:new) { double.as_null_object }
    end

    context "without any open sections specified" do
      it "renders all sections closed" do
        expect(rendered).not_to have_css("details[open]")
      end
    end

    context "with specified open sections" do
      let(:open_sections) { [:new_records] }

      it "renders specified sections open" do
        expect(rendered).to have_css("details[open]")
      end
    end
  end
end
