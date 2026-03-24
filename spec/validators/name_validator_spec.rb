# frozen_string_literal: true

describe NameValidator do
  describe "#validate_each" do
    context "for person names (default)" do
      let(:validator) { described_class.new(attributes: [:name]) }
      let(:record) { build(:patient) }

      context "with valid person names" do
        valid_names = [
          "John O'Brien",
          "Mary-Jane Smith",
          "École Française",
          "Smith Jr."
        ]

        valid_names.each do |name|
          it "allows '#{name}'" do
            validator.validate_each(record, :given_name, name)
            expect(record.errors[:given_name]).to be_empty
          end
        end
      end

      context "with ampersand or comma" do
        it "rejects names with ampersand" do
          validator.validate_each(record, :given_name, "John & Jane")
          expect(record.errors[:given_name]).to include(
            "includes invalid character(s)"
          )
        end

        it "rejects names with comma" do
          validator.validate_each(record, :given_name, "Smith, John")
          expect(record.errors[:given_name]).to include(
            "includes invalid character(s)"
          )
        end
      end

      context "with invalid characters" do
        it "rejects names with special symbols" do
          validator.validate_each(record, :given_name, "Name with @ symbol")
          expect(record.errors[:given_name]).to include(
            "includes invalid character(s)"
          )
        end
      end

      context "with blank names" do
        it "allows blank values" do
          validator.validate_each(record, :given_name, nil)
          expect(record.errors[:given_name]).to be_empty

          validator.validate_each(record, :given_name, "")
          expect(record.errors[:given_name]).to be_empty
        end
      end
    end

    context "for school names (school_name: true)" do
      let(:validator) do
        described_class.new(attributes: [:name], school_name: true)
      end
      let(:record) { build(:gias_school) }

      context "with valid school names" do
        context "with valid school names" do
          valid_names = [
            "St. John & St. Mary's",
            "School, Site A",
            "École Française School (Site B)",
            "All Saints: Secondary; Main site."
          ]

          valid_names.each do |name|
            it "allows '#{name}'" do
              validator.validate_each(record, :name, name)
              expect(record.errors[:name]).to be_empty
            end
          end
        end
      end

      context "with invalid characters" do
        it "rejects names with special symbols" do
          validator.validate_each(record, :name, "School with [ ]")
          expect(record.errors[:name]).to include(
            "includes invalid character(s)"
          )
        end
      end
    end
  end
end
