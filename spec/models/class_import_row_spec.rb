# frozen_string_literal: true

describe ClassImportRow do
  subject(:class_import_row) do
    described_class.new(
      data: data_as_csv_row,
      team: session.team,
      academic_year:,
      location: session.location,
      year_groups: session.year_groups
    )
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

  let(:programmes) { [Programme.sample] }
  let(:team) { create(:team, programmes:) }
  let(:academic_year) { AcademicYear.pending }
  let(:school) { create(:gias_school, team:) }
  let(:session) { create(:session, team:, programmes:, location: school) }

  let(:valid_data) do
    {
      "CHILD_DATE_OF_BIRTH" => "2010-01-01",
      "CHILD_FIRST_NAME" => "Jimmy",
      "CHILD_LAST_NAME" => "Smith",
      "CHILD_POSTCODE" => "SW1A 1AA",
      "CHILD_REGISTRATION" => "8AB",
      "PARENT_1_EMAIL" => "john@example.com",
      "PARENT_1_PHONE" => "07412345678"
    }
  end

  let(:parent_2_data) do
    {
      "PARENT_2_EMAIL" => "jenny@example.com",
      "PARENT_2_PHONE" => "07412345678"
    }
  end

  describe "validations" do
    let(:data) { valid_data }

    it { should be_valid }

    context "when date of birth is outside the programme year group" do
      let(:data) { valid_data.merge("CHILD_DATE_OF_BIRTH" => "2000-01-01") }

      it "is invalid" do
        expect(class_import_row).to be_invalid
        expect(
          class_import_row.errors["CHILD_DATE_OF_BIRTH"]
        ).to contain_exactly("is not part of this programme")
      end
    end

    context "when date of birth is not a date" do
      let(:data) { valid_data.merge("CHILD_DATE_OF_BIRTH" => "DDDDDDD") }

      it "is invalid" do
        expect(class_import_row).to be_invalid
        expect(class_import_row.errors.size).to eq(1)
        expect(
          class_import_row.errors["CHILD_DATE_OF_BIRTH"]
        ).to contain_exactly("should be formatted as YYYY-MM-DD")
      end
    end

    context "with an invalid NHS number" do
      let(:data) { { "CHILD_NHS_NUMBER" => "TP01234567" } }

      it "has errors" do
        expect(class_import_row).to be_invalid
        expect(class_import_row.errors["CHILD_NHS_NUMBER"]).to eq(
          ["should be a valid NHS number with 10 characters"]
        )
      end
    end

    context "with an invalid postcode" do
      let(:data) { valid_data.merge("CHILD_POSTCODE" => "not a postcode") }

      it "is invalid" do
        expect(class_import_row).to be_invalid
        expect(class_import_row.errors.size).to eq(1)
        expect(class_import_row.errors["CHILD_POSTCODE"]).to contain_exactly(
          "should be a postcode, like SW1A 1AA"
        )
      end
    end

    ["ZZ99 3VZ", "ZZ99 3WZ", "ZZ99 3CZ"].each do |pseudo_postcode|
      context "with a pseudo-postcode" do
        let(:data) { valid_data.merge("CHILD_POSTCODE" => pseudo_postcode) }

        it "is invalid" do
          expect(class_import_row).to be_valid
        end
      end
    end

    context "with an invalid year group" do
      let(:data) { valid_data.merge("CHILD_YEAR_GROUP" => "abc") }

      it "is invalid" do
        expect(class_import_row).to be_invalid
        expect(class_import_row.errors.size).to eq(1)
        expect(class_import_row.errors["CHILD_YEAR_GROUP"]).to contain_exactly(
          "is not a valid year group"
        )
      end
    end

    context "vaccination in a session where name-like fields have length greater than 300" do
      let(:invalid_name_length) { "a" * 301 }
      let(:data) do
        {
          "CHILD_FIRST_NAME" => invalid_name_length,
          "CHILD_LAST_NAME" => invalid_name_length
        }
      end

      it "has errors" do
        expect(class_import_row).to be_invalid
        expect(class_import_row.errors["CHILD_FIRST_NAME"]).to include(
          "is greater than 300 characters long"
        )
        expect(class_import_row.errors["CHILD_LAST_NAME"]).to include(
          "is greater than 300 characters long"
        )
      end
    end
  end
end
