# frozen_string_literal: true

describe AppImportFormatDetailsComponent do
  let(:programme) { Programme.hpv }
  let(:team) { create(:team, programmes: [programme]) }

  it "renders the correct summary text" do
    import = ClassImport.new(team:)
    render_inline(described_class.new(import:))
    expect(page).to have_content("What your CSV file must include")
  end

  it "renders the correct columns for ClassImport" do
    import = ClassImport.new(team:)
    render_inline(described_class.new(import:))
    expect(page).to have_content("CHILD_FIRST_NAME")
    expect(page).to have_content("CHILD_LAST_NAME")
    expect(page).to have_content("CHILD_DATE_OF_BIRTH")
    expect(page).to have_content("CHILD_YEAR_GROUP")
    expect(page).to have_content("CHILD_REGISTRATION")
    expect(page).to have_content("CHILD_POSTCODE")
    expect(page).to have_content("PARENT_1_EMAIL")
    expect(page).to have_content("PARENT_1_PHONE")
  end

  it "renders the correct columns for CohortImport" do
    import = CohortImport.new(team:)
    render_inline(described_class.new(import:))
    expect(page).to have_content("CHILD_FIRST_NAME")
    expect(page).to have_content("CHILD_LAST_NAME")
    expect(page).to have_content("CHILD_DATE_OF_BIRTH")
    expect(page).to have_content("CHILD_YEAR_GROUP")
    expect(page).to have_content("CHILD_REGISTRATION")
    expect(page).to have_content("CHILD_POSTCODE")
    expect(page).to have_content("CHILD_SCHOOL_URN")
    expect(page).to have_content("PARENT_1_NAME")
    expect(page).to have_content("PARENT_2_NAME")
  end

  it "renders the correct columns for ImmunisationImport" do
    import = ImmunisationImport.new(team:)
    render_inline(described_class.new(import:))
    expect(page).to have_content("ORGANISATION_CODE")
    expect(page).to have_content("SCHOOL_URN")
    expect(page).to have_content("PERSON_FORENAME")
    expect(page).to have_content("PERSON_SURNAME")
    expect(page).to have_content("DATE_OF_VACCINATION")
    expect(page).to have_content("VACCINE_GIVEN")
    expect(page).to have_content("CARE_SETTING")
    expect(page).to have_content("CLINIC_NAME")

    # Excluded point of care columns
    expect(page).not_to have_content("LOCAL_PATIENT_ID")
    expect(page).not_to have_content("LOCAL_PATIENT_ID_URI")
  end

  context "with a national reporting team" do
    let(:team) { create(:team, :national_reporting, programmes: [programme]) }

    it "renders the correct columns for ImmunisationImport" do
      import = ImmunisationImport.new(team:)
      render_inline(described_class.new(import:))

      # Required national reporting columns
      expect(page).to have_content("ORGANISATION_CODE")
      expect(page).to have_content("SCHOOL_URN")
      expect(page).to have_content("NHS_NUMBER")
      expect(page).to have_content("PERSON_FORENAME")
      expect(page).to have_content("PERSON_SURNAME")
      expect(page).to have_content("PERSON_DOB")
      expect(page).to have_content("PERSON_GENDER")
      expect(page).to have_content("PERSON_POSTCODE")
      expect(page).to have_content("VACCINATED")
      expect(page).to have_content("DATE_OF_VACCINATION")
      expect(page).to have_content("TIME_OF_VACCINATION")
      expect(page).to have_content("VACCINE_GIVEN")
      expect(page).to have_content("BATCH_NUMBER")
      expect(page).to have_content("BATCH_EXPIRY_DATE")
      expect(page).to have_content("ANATOMICAL_SITE")
      expect(page).to have_content("DOSE_SEQUENCE")
      expect(page).to have_content("PERFORMING_PROFESSIONAL_FORENAME")
      expect(page).to have_content("PERFORMING_PROFESSIONAL_SURNAME")
      expect(page).to have_content("LOCAL_PATIENT_ID")
      expect(page).to have_content("LOCAL_PATIENT_ID_URI")

      # Excluded point of care columns
      expect(page).not_to have_content("CARE_SETTING")
      expect(page).not_to have_content("CLINIC_NAME")
      expect(page).not_to have_content("SCHOOL_NAME")
      expect(page).not_to have_content("PROGRAMME")
      expect(page).not_to have_content("REASON_NOT_VACCINATED")
      expect(page).not_to have_content("NOTES")
      expect(page).not_to have_content("PERFORMING_PROFESSIONAL_EMAIL")
    end
  end
end
