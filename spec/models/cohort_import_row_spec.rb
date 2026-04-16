# frozen_string_literal: true

describe CohortImportRow do
  subject(:cohort_import_row) do
    described_class.new(data: data_as_csv_row, team:, academic_year:)
  end

  # FIXME: Don't re-implement behaviour of `CSVParser`.
  let(:data_as_csv_row) do
    data.each_with_object({}) do |(key, value), hash|
      hash[
        key.strip.downcase.tr("-", "_").tr(" ", "_").to_sym
      ] = CSVParser::Field.new(value, nil, nil, key)
    end
  end

  let(:today) { Date.new(2024, 12, 1) }

  let(:programme) { Programme.sample }
  let(:team) { create(:team, programmes: [programme]) }
  let(:academic_year) { AcademicYear.pending }

  let(:school_urn) { "123456" }

  let(:valid_data) do
    {
      "CHILD_ADDRESS_LINE_1" => "10 Downing Street",
      "CHILD_ADDRESS_LINE_2" => "",
      "CHILD_TOWN" => "London",
      "CHILD_POSTCODE" => "SW1A 1AA",
      "CHILD_FIRST_NAME" => "Jimmy",
      "CHILD_LAST_NAME" => "Smith",
      "CHILD_PREFERRED_FIRST_NAME" => "Jim",
      "CHILD_PREFERRED_LAST_NAME" => "Smithy",
      "CHILD_DATE_OF_BIRTH" => "2010-01-01",
      "CHILD_GENDER" => "Male",
      "CHILD_NHS_NUMBER" => "9990000018",
      "CHILD_REGISTRATION" => "8AB",
      "CHILD_SCHOOL_URN" => school_urn
    }
  end

  let(:parent_1_data) do
    {
      "PARENT_1_EMAIL" => "john@example.com",
      "PARENT_1_NAME" => "John Smith",
      "PARENT_1_PHONE" => "07412345678",
      "PARENT_1_RELATIONSHIP" => "Father"
    }
  end

  let(:parent_2_data) do
    {
      "PARENT_2_EMAIL" => "jenny@example.com",
      "PARENT_2_NAME" => "Jenny Smith",
      "PARENT_2_PHONE" => "07412345678",
      "PARENT_2_RELATIONSHIP" => "Mother"
    }
  end

  let!(:school) { create(:gias_school, urn: "123456", team:) }

  describe "validations" do
    let(:data) { valid_data }

    it { should be_valid }

    context "when date of birth is outside the programme year group" do
      let(:data) { valid_data.merge("CHILD_DATE_OF_BIRTH" => "2000-01-01") }

      it "is invalid" do
        expect(cohort_import_row).to be_invalid
        expect(
          cohort_import_row.errors["CHILD_DATE_OF_BIRTH"]
        ).to contain_exactly("is not part of this programme")
      end
    end

    context "when date of birth is not a date" do
      let(:data) { valid_data.merge("CHILD_DATE_OF_BIRTH" => "DDDDDDD") }

      it "is invalid" do
        expect(cohort_import_row).to be_invalid
        expect(cohort_import_row.errors.size).to eq(1)
        expect(
          cohort_import_row.errors["CHILD_DATE_OF_BIRTH"]
        ).to contain_exactly("should be formatted as YYYY-MM-DD")
      end
    end

    context "when date of birth is in the previous century" do
      let(:data) do
        valid_data.merge(
          { "CHILD_DATE_OF_BIRTH" => "1911-01-01", "CHILD_YEAR_GROUP" => "9" }
        )
      end

      it "is invalid" do
        expect(cohort_import_row).to be_invalid
        expect(cohort_import_row.errors.size).to eq(1)
        expect(
          cohort_import_row.errors["CHILD_DATE_OF_BIRTH"]
        ).to contain_exactly("is too old to still be in school")
      end
    end

    context "with an invalid NHS number" do
      let(:data) { { "CHILD_NHS_NUMBER" => "TP01234567" } }

      it "has errors" do
        expect(cohort_import_row).to be_invalid
        expect(cohort_import_row.errors["CHILD_NHS_NUMBER"]).to eq(
          ["should be a valid NHS number with 10 characters"]
        )
      end
    end

    context "with an invalid school URN" do
      let(:data) { valid_data.merge("CHILD_SCHOOL_URN" => "123456789") }

      it "is invalid" do
        expect(cohort_import_row).to be_invalid
        expect(cohort_import_row.errors.size).to eq(1)
        expect(cohort_import_row.errors["CHILD_SCHOOL_URN"]).to contain_exactly(
          "The school URN is not recognised. If you’ve checked the URN, " \
            "and you believe it’s valid, contact our support team."
        )
      end
    end

    context "with a school for a different team" do
      let(:data) { valid_data }

      before { school.team_locations.includes(:team).destroy_all }

      it "is invalid" do
        expect(cohort_import_row).to be_invalid
        expect(cohort_import_row.errors["CHILD_SCHOOL_URN"].first).to include(
          "The school URN is not recognised."
        )
      end
    end

    context "with a school that has sites and parent school URN used" do
      let(:data) { valid_data }

      before do
        school.team_locations.includes(:team).destroy_all
        create(:gias_school, urn: school_urn, site: "A", team:)
        create(:gias_school, urn: school_urn, site: "B", team:)
      end

      it "is invalid" do
        expect(cohort_import_row).to be_invalid
        expect(cohort_import_row.errors["CHILD_SCHOOL_URN"].first).to include(
          "Use 123456A or 123456B instead."
        )
      end
    end

    context "with a school that has sites and site URN used" do
      let(:data) { valid_data.merge("CHILD_SCHOOL_URN" => "#{school_urn}A") }

      before do
        school.team_locations.includes(:team).destroy_all
        create(:gias_school, urn: school_urn, site: "A", team:)
        create(:gias_school, urn: school_urn, site: "B", team:)
      end

      it "is valid" do
        expect(cohort_import_row).to be_valid
      end
    end

    context "with an invalid year group" do
      let(:data) { valid_data.merge("CHILD_YEAR_GROUP" => "abc") }

      it "is invalid" do
        expect(cohort_import_row).to be_invalid
        expect(cohort_import_row.errors.size).to eq(1)
        expect(cohort_import_row.errors["CHILD_YEAR_GROUP"]).to contain_exactly(
          "is not a valid year group"
        )
      end
    end

    context "when the given name has invalid characters" do
      let(:data) { valid_data.merge("CHILD_FIRST_NAME" => "J£mmy") }

      it "is invalid" do
        expect(cohort_import_row).to be_invalid
        expect(cohort_import_row.errors.size).to eq(1)
        expect(cohort_import_row.errors["CHILD_FIRST_NAME"]).to contain_exactly(
          "includes invalid character(s)"
        )
      end
    end

    context "when the family name has invalid characters" do
      let(:data) { valid_data.merge("CHILD_LAST_NAME" => "ᶚmith") }

      it "is invalid" do
        expect(cohort_import_row).to be_invalid
        expect(cohort_import_row.errors.size).to eq(1)
        expect(cohort_import_row.errors["CHILD_LAST_NAME"]).to contain_exactly(
          "includes invalid character(s)"
        )
      end
    end

    context "when the preferred given name has invalid characters" do
      let(:data) { valid_data.merge("CHILD_PREFERRED_FIRST_NAME" => "J£m") }

      it "is invalid" do
        expect(cohort_import_row).to be_invalid
        expect(cohort_import_row.errors.size).to eq(1)
        expect(
          cohort_import_row.errors["CHILD_PREFERRED_FIRST_NAME"]
        ).to contain_exactly("includes invalid character(s)")
      end
    end

    context "when the preferred family name has invalid characters" do
      let(:data) { valid_data.merge("CHILD_PREFERRED_LAST_NAME" => "ᶚmithy") }

      it "is invalid" do
        expect(cohort_import_row).to be_invalid
        expect(cohort_import_row.errors.size).to eq(1)
        expect(
          cohort_import_row.errors["CHILD_PREFERRED_LAST_NAME"]
        ).to contain_exactly("includes invalid character(s)")
      end
    end

    context "when the first parent's full name has invalid characters" do
      let(:data) do
        valid_data.merge(parent_1_data).merge("PARENT_1_NAME" => "John© Smith")
      end

      it "is invalid" do
        expect(cohort_import_row).to be_invalid
        expect(cohort_import_row.errors.size).to eq(1)
        expect(cohort_import_row.errors["PARENT_1_NAME"]).to contain_exactly(
          "includes invalid character(s)"
        )
      end
    end

    context "when the second parent's full name has invalid characters" do
      let(:data) do
        valid_data.merge(parent_2_data).merge("PARENT_2_NAME" => "John© Smith")
      end

      it "is invalid" do
        expect(cohort_import_row).to be_invalid
        expect(cohort_import_row.errors.size).to eq(1)
        expect(cohort_import_row.errors["PARENT_2_NAME"]).to contain_exactly(
          "includes invalid character(s)"
        )
      end
    end
  end

  describe "#import_attributes" do
    context "with fancy apostrophes" do
      let(:data) do
        valid_data.merge(
          {
            "CHILD_FIRST_NAME" => "Mickʼee",
            "CHILD_LAST_NAME" => "OʼReilly",
            "CHILD_PREFERRED_FIRST_NAME" => "Mickʼee",
            "CHILD_PREFERRED_LAST_NAME" => "OʼReilly"
          }
        )
      end

      it "converts fancy apostrophes to plain apostrophes" do
        expect(cohort_import_row.import_attributes).to include(
          given_name: "Mick'ee",
          family_name: "O'Reilly",
          preferred_given_name: "Mick'ee",
          preferred_family_name: "O'Reilly"
        )
      end
    end
  end
end
