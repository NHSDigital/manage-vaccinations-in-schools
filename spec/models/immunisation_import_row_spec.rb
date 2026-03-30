# frozen_string_literal: true

describe ImmunisationImportRow do
  subject(:immunisation_import_row) do
    described_class.new(data: data_as_csv_row, team:, type: import_type)
  end

  # FIXME: Don't re-implement behaviour of `CSVParser`.
  let(:data_as_csv_row) do
    data.each_with_object({}) do |(key, value), hash|
      hash[
        key.strip.downcase.tr("-", "_").tr(" ", "_").to_sym
      ] = CSVParser::Field.new(value, nil, nil, key)
    end
  end

  let(:programmes) { [Programme.hpv] }
  let(:team) { create(:team, ods_code: "ABC", programmes:) }

  let(:nhs_number) { "9449306168" }
  let(:given_name) { "Harry" }
  let(:family_name) { "Potter" }
  let(:date_of_birth) { "20120101" }
  let(:address_postcode) { "SW1A 1AA" }
  let(:vaccinator) { create(:user, team:) }
  let(:valid_patient_data) do
    {
      "ORGANISATION_CODE" => "ABC",
      "SCHOOL_NAME" => "Hogwarts",
      "SCHOOL_URN" => "123456",
      "PERSON_FORENAME" => given_name,
      "PERSON_SURNAME" => family_name,
      "PERSON_DOB" => date_of_birth,
      "PERSON_POSTCODE" => address_postcode,
      "PERSON_GENDER_CODE" => "Male",
      "NHS_NUMBER" => nhs_number
    }
  end
  let(:valid_common_data) do
    valid_patient_data.deep_dup.merge(
      "VACCINATED" => "Y",
      "BATCH_EXPIRY_DATE" => "20210101",
      "BATCH_NUMBER" => "123"
    )
  end
  let(:valid_flu_data) do
    valid_common_data.deep_dup.merge(
      "ANATOMICAL_SITE" => "nasal",
      "BATCH_EXPIRY_DATE" => Date.tomorrow.iso8601,
      "DATE_OF_VACCINATION" => Date.current.iso8601,
      "PERFORMING_PROFESSIONAL_FORENAME" => "John",
      "PERFORMING_PROFESSIONAL_SURNAME" => "Smith",
      "PROGRAMME" => "Flu",
      "VACCINE_GIVEN" => "AstraZeneca Fluenz"
    )
  end
  let(:valid_hpv_data) do
    valid_common_data.deep_dup.merge(
      "ANATOMICAL_SITE" => "Left Upper Arm",
      "CARE_SETTING" => "1",
      "DATE_OF_VACCINATION" => "20240101",
      "DOSE_SEQUENCE" => "1",
      "PROGRAMME" => "HPV",
      "VACCINE_GIVEN" => "Gardasil9"
    )
  end
  let(:valid_data) { valid_hpv_data }

  let(:valid_national_reporting_common_data) do
    valid_patient_data.deep_dup.merge(
      "BATCH_EXPIRY_DATE" => "20260106",
      "DATE_OF_VACCINATION" => "20260105",
      "BATCH_NUMBER" => "123",
      "LOCAL_PATIENT_ID" => "CIN-OXFORD-pat123456",
      "LOCAL_PATIENT_ID_URI" => "https://cinnamon.nhs.uk/0de/system1"
    )
  end
  let(:valid_national_reporting_flu_data) do
    valid_national_reporting_common_data.deep_dup.merge(
      "VACCINATED" => "Y",
      "PERFORMING_PROFESSIONAL_FORENAME" => vaccinator.given_name,
      "PERFORMING_PROFESSIONAL_SURNAME" => vaccinator.family_name,
      "VACCINE_GIVEN" => "AstraZeneca Fluenz LAIV",
      "ANATOMICAL_SITE" => "nasal"
    )
  end
  let(:valid_national_reporting_hpv_data) do
    valid_national_reporting_common_data.deep_dup.merge(
      "VACCINE_GIVEN" => "Gardasil9",
      "ANATOMICAL_SITE" => "Left Deltoid",
      "DOSE_SEQUENCE" => "1",
      "CARE_SETTING" => "1" # School
    )
  end

  let!(:location) do
    create(:school, urn: "123456", name: "Waterloo Road", programmes:)
  end

  let(:import_type) { "point_of_care" }

  describe "validations" do
    context "for a point_of_care upload" do
      let(:import_type) { "point_of_care" }

      context "with an empty spreadsheet" do
        let(:data) { {} }

        it "has errors" do
          expect(immunisation_import_row).to be_invalid
          expect(immunisation_import_row.errors[:base]).to contain_exactly(
            "<code>VACCINATED</code> is required",
            "<code>DATE_OF_VACCINATION</code> or <code>Event date</code> is required",
            "<code>PERSON_DOB</code> or <code>Date of birth</code> is required",
            "<code>PERSON_FORENAME</code> or <code>First name</code> is required",
            "<code>PERSON_GENDER_CODE</code>, <code>PERSON_GENDER</code> or <code>Sex</code> is required",
            "<code>PERSON_SURNAME</code> or <code>Surname</code> is required",
            "<code>PERSON_POSTCODE</code> or <code>Postcode</code> is required",
            "<code>PROGRAMME</code> or <code>Vaccination type</code> is required",
            "<code>REASON_NOT_VACCINATED</code> is required"
          )
        end
      end

      context "with headers, but an empty row" do
        let(:data) do
          {
            "ORGANISATION_CODE" => "",
            "SCHOOL_NAME" => "",
            "SCHOOL_URN" => "",
            "NHS_NUMBER" => "",
            "PERSON_FORENAME" => "",
            "PERSON_SURNAME" => "",
            "PERSON_DOB" => "",
            "PERSON_POSTCODE" => "",
            "PERSON_GENDER_CODE" => "",
            "PROGRAMME" => "",
            "DATE_OF_VACCINATION" => "",
            "REASON_NOT_VACCINATED" => "",
            "VACCINATED" => "",
            "BATCH_EXPIRY_DATE" => "",
            "BATCH_NUMBER" => "",
            "ANATOMICAL_SITE" => "",
            "PERFORMING_PROFESSIONAL_FORENAME" => "",
            "PERFORMING_PROFESSIONAL_SURNAME" => "",
            "VACCINE_GIVEN" => ""
          }
        end

        it "has the correct errors" do
          expect(immunisation_import_row).to be_invalid

          expect(immunisation_import_row.errors.to_hash).to eq(
            {
              VACCINATED: [
                "You need to record whether the child was vaccinated or not. " \
                  "Enter ‘Y’ or ‘N’ in the ‘VACCINATED’ column."
              ],
              DATE_OF_VACCINATION: ["Enter a date."],
              PERSON_DOB: ["Enter a date of birth."],
              PERSON_FORENAME: ["Enter a first name."],
              PERSON_GENDER_CODE: ["Enter a gender or gender code."],
              PERSON_SURNAME: ["Enter a last name."],
              PERSON_POSTCODE: ["Enter a valid postcode, such as SW1A 1AA."],
              PROGRAMME: ["Enter a programme."],
              REASON_NOT_VACCINATED: ["Enter a valid reason."]
            }
          )
        end
      end

      context "when missing VACCINATED but a vaccine has been given" do
        let(:data) { { "VACCINE_GIVEN" => "A vaccine" } }

        it "doesn't require a VACCINATED column" do
          expect(immunisation_import_row).to be_invalid
          expect(immunisation_import_row.errors[:base]).not_to include(
            "<code>VACCINATED</code> is required"
          )
        end
      end

      context "when missing VACCINATED but a vaccination type has been given" do
        let(:data) { { "Vaccination type" => "HPV 1" } }

        it "doesn't require a VACCINATED column" do
          expect(immunisation_import_row).to be_invalid
          expect(immunisation_import_row.errors[:base]).not_to include(
            "<code>VACCINATED</code> is required"
          )
        end
      end

      context "when missing fields" do
        let(:data) { { "VACCINATED" => "Y" } }

        it { should be_invalid }

        context "with an NHS number and missing fields" do
          let(:data) { { "VACCINATED" => "Y", "NHS_NUMBER" => nhs_number } }

          it "doesn't require a postcode" do
            expect(immunisation_import_row).to be_invalid
            expect(immunisation_import_row.errors[:base]).not_to include(
              "<code>PERSON_POSTCODE</code> is required"
            )
          end
        end
      end

      context "with an invalid vaccine" do
        let(:data) { { "VACCINATED" => "Y", "VACCINE_GIVEN" => "test" } }

        it "has errors" do
          expect(immunisation_import_row).to be_invalid
          expect(immunisation_import_row.errors["VACCINE_GIVEN"]).to eq(
            ["This vaccine is not valid."]
          )
        end
      end

      context "with a vaccine name in a different case" do
        let(:data) { valid_hpv_data.merge("VACCINE_GIVEN" => "gardasil9") }

        it { should be_valid }
      end

      context "with an invalid vaccine for the programme" do
        let(:data) do
          { "PROGRAMME" => "HPV", "VACCINE_GIVEN" => "AstraZeneca Fluenz" }
        end

        let(:programmes) { [Programme.flu, Programme.hpv] }

        it "has errors" do
          expect(immunisation_import_row).to be_invalid
          expect(
            immunisation_import_row.errors["VACCINE_GIVEN"]
          ).to contain_exactly("is not given in the HPV programme")
        end
      end

      context "without a vaccine" do
        let(:data) { valid_data.except("VACCINE_GIVEN") }

        it { should be_valid }
      end

      context "without a vaccine and recording offline" do
        let(:data) do
          valid_data.merge(
            "VACCINE_GIVEN" => "",
            "DATE_OF_VACCINATION" => "#{AcademicYear.current}0901",
            "SESSION_ID" => session.id.to_s
          )
        end

        let(:session) { create(:session, team:, programmes:) }

        it "has errors" do
          expect(immunisation_import_row).to be_invalid
          expect(immunisation_import_row.errors["VACCINE_GIVEN"]).to eq(
            ["Enter a vaccine name."]
          )
        end
      end

      context "without a vaccine with MMRV programme variant" do
        let(:programmes) { [Programme.mmr] }
        let(:data) do
          valid_data.except("VACCINE_GIVEN").merge("PROGRAMME" => "MMRV")
        end

        it { should be_valid }
      end

      context "with an invalid reason not vaccinated" do
        let(:data) do
          { "VACCINATED" => "N", "REASON_NOT_VACCINATED" => "unknown" }
        end

        it "has errors" do
          expect(immunisation_import_row).to be_invalid
          expect(immunisation_import_row.errors["REASON_NOT_VACCINATED"]).to eq(
            ["Enter a valid reason."]
          )
        end
      end

      context "with an invalid batch name" do
        let(:data) { { "VACCINATED" => "Y", "BATCH_NUMBER" => "[invalid]" } }

        it "has errors" do
          expect(immunisation_import_row).to be_invalid
          expect(immunisation_import_row.errors["BATCH_NUMBER"]).to eq(
            ["must be only letters and numbers"]
          )
        end
      end

      context "with an invalid postcode" do
        let(:data) { { "PERSON_POSTCODE" => "ABC DEF" } }

        it "has errors" do
          expect(immunisation_import_row).to be_invalid
          expect(immunisation_import_row.errors["PERSON_POSTCODE"]).to include(
            "Enter a valid postcode, such as SW1A 1AA."
          )
        end
      end

      context "with an invalid gender code" do
        let(:data) { { "PERSON_GENDER_CODE" => "10" } }

        it "has errors" do
          expect(immunisation_import_row).to be_invalid
          expect(immunisation_import_row.errors["PERSON_GENDER_CODE"]).to eq(
            ["Enter a valid gender or gender code."]
          )
        end
      end

      context "with an invalid date of vaccination" do
        let(:data) { { "DATE_OF_VACCINATION" => "21000101" } }

        it { should be_invalid }
      end

      context "with a date and time of vaccination in the future" do
        around { |example| freeze_time { example.run } }

        let(:data) do
          {
            "DATE_OF_VACCINATION" => Date.current.strftime("%Y%m%d"),
            "TIME_OF_VACCINATION" => 1.second.from_now.strftime("%H:%M:%S")
          }
        end

        it "has an error" do
          expect(immunisation_import_row).to be_invalid
          expect(
            immunisation_import_row.errors["TIME_OF_VACCINATION"]
          ).to include("Enter a time in the past.")
        end
      end

      context "with a date of vaccination before the child was born" do
        around { |example| freeze_time { example.run } }

        let(:data) do
          { "PERSON_DOB" => "20100101", "DATE_OF_VACCINATION" => "20090101" }
        end

        it "has an error" do
          expect(immunisation_import_row).to be_invalid
          expect(
            immunisation_import_row.errors["DATE_OF_VACCINATION"]
          ).to include("The vaccination date is before the date of birth.")
        end
      end

      context "when vaccinated and a reason not given" do
        let(:data) do
          { "VACCINATED" => "Y", "REASON_NOT_VACCINATED" => "unwell" }
        end

        it "has errors" do
          expect(immunisation_import_row).to be_invalid
          expect(immunisation_import_row.errors["REASON_NOT_VACCINATED"]).to eq(
            ["must be blank"]
          )
        end
      end

      context "for a vaccination administered today, with no time provided" do
        around { |example| freeze_time { example.run } }

        before { immunisation_import_row.valid? }

        let(:data) do
          {
            "DATE_OF_VACCINATION" => Date.current.strftime("%Y%m%d"),
            "TIME_OF_VACCINATION" => nil
          }
        end

        it "has a valid time of vaccination" do
          expect(
            immunisation_import_row.errors["TIME_OF_VACCINATION"]
          ).to be_empty
        end
      end

      context "when date doesn't match an existing session" do
        subject(:errors) do
          immunisation_import_row.errors["DATE_OF_VACCINATION"]
        end

        before { immunisation_import_row.valid? }

        context "when importing for an existing session" do
          around { |example| travel_to(Date.new(2025, 9, 1)) { example.run } }

          let(:data) do
            {
              "DATE_OF_VACCINATION" => "20250902",
              "SESSION_ID" => session.id.to_s
            }
          end

          let(:session) { create(:session, team:, programmes:) }

          it do
            expect(errors).to include(
              "Enter a date that matches when the vaccination session took place."
            )
          end
        end

        context "when importing without a session" do
          let(:data) { { "DATE_OF_VACCINATION" => "20220101" } }

          it { should be_empty }
        end
      end

      context "with an invalid time of vaccination" do
        let(:data) { { "TIME_OF_VACCINATION" => "abc" } }

        it "has errors" do
          expect(immunisation_import_row).to be_invalid
          expect(immunisation_import_row.errors["TIME_OF_VACCINATION"]).to eq(
            ["Enter a time in the correct format."]
          )
        end
      end

      context "with an invalid NHS number" do
        let(:data) { { "NHS_NUMBER" => "TP01234567" } }

        it "has errors" do
          expect(immunisation_import_row).to be_invalid
          expect(immunisation_import_row.errors["NHS_NUMBER"]).to eq(
            ["should be a valid NHS number with 10 characters"]
          )
        end
      end

      context "with an invalid patient date of birth" do
        let(:data) { { "PERSON_DOB" => "21000101" } }

        it "has errors" do
          expect(immunisation_import_row).to be_invalid
          expect(immunisation_import_row.errors["PERSON_DOB"]).to eq(
            ["Enter a date of birth in the past."]
          )
        end
      end

      context "when recording offline in to a clinic" do
        let(:valid_clinic_data) do
          valid_data.merge(
            "CARE_SETTING" => "2",
            "DATE_OF_VACCINATION" => Date.current.strftime("%Y%m%d"),
            "SESSION_ID" => "clinic",
            "ORGANISATION_CODE" => team.organisation.ods_code,
            "PERFORMING_PROFESSIONAL_EMAIL" => create(:user).email
          )
        end

        before { create(:community_clinic, name: "A clinic", team:) }

        context "with an existing community clinic" do
          let(:data) { valid_clinic_data.merge("CLINIC_NAME" => "A clinic") }

          it "is matching" do
            expect(immunisation_import_row).to be_valid
          end
        end

        context "on a different day to today" do
          let(:data) do
            valid_clinic_data.merge(
              "CLINIC_NAME" => "A clinic",
              "DATE_OF_VACCINATION" => Date.yesterday.strftime("%Y%m%d")
            )
          end

          it "is valid" do
            expect(immunisation_import_row).to be_valid
          end
        end

        context "with incorrect casing for an existing clinic" do
          let(:data) { valid_clinic_data.merge("CLINIC_NAME" => "a cLinIC") }

          it "is case insensitive" do
            expect(immunisation_import_row).to be_valid
          end
        end

        context "with a non-existent clinic" do
          let(:data) do
            valid_clinic_data.merge("CLINIC_NAME" => "A wrong clinic")
          end

          it "is invalid" do
            expect(immunisation_import_row).to be_invalid

            expect(
              immunisation_import_row.errors["CLINIC_NAME"]
            ).to contain_exactly("is not recognised")
          end
        end
      end

      context "with more than two matching patients" do
        let(:data) do
          {
            "PERSON_FORENAME" => "John",
            "PERSON_SURNAME" => "Smith",
            "PERSON_DOB" => "19900901",
            "PERSON_POSTCODE" => "ABC DEF"
          }
        end

        before do
          create_list(
            :patient,
            2,
            given_name: "John",
            family_name: "Smith",
            date_of_birth: Date.new(1990, 9, 1)
          )
        end

        it "has errors" do
          expect(immunisation_import_row).to be_invalid
          expect(immunisation_import_row.errors[:base]).to include(
            "Two or more possible patients match the patient first name, last name, date of birth and postcode."
          )
        end
      end

      context "with an invalid dose sequence" do
        let(:programmes) { [Programme.hpv] }

        let(:data) { { "PROGRAMME" => "HPV", "DOSE_SEQUENCE" => "4" } }

        it "has errors" do
          expect(immunisation_import_row).to be_invalid
          expect(immunisation_import_row.errors["DOSE_SEQUENCE"]).to include(
            /must be less than or equal to/
          )
        end
      end

      context "with an invalid session ID" do
        let(:data) { { "SESSION_ID" => "abc" } }

        it "has errors" do
          expect(immunisation_import_row).to be_invalid
          expect(immunisation_import_row.errors["SESSION_ID"]).to include(
            "The session ID is not recognised. Download the offline spreadsheet and copy the session ID " \
              "for this row from there, or contact our support team."
          )
        end
      end

      context "with a session ID that doesn't exist" do
        let(:data) { { "SESSION_ID" => "123" } }

        it "has errors" do
          expect(immunisation_import_row).to be_invalid
          expect(immunisation_import_row.errors["SESSION_ID"]).to include(
            "The session ID is not recognised. Download the offline spreadsheet and copy the session ID " \
              "for this row from there, or contact our support team."
          )
        end
      end

      context "vaccination in a session and no team provided" do
        let(:data) { { "SESSION_ID" => session.id.to_s } }

        let(:session) { create(:session, team:, programmes:) }

        it "has errors" do
          expect(immunisation_import_row).to be_invalid
          expect(immunisation_import_row.errors[:base]).to include(
            "<code>ORGANISATION_CODE</code> is required"
          )
        end
      end

      context "vaccination in a session and invalid programme" do
        let(:data) do
          { "SESSION_ID" => session.id.to_s, "PROGRAMME" => "MenACWY" }
        end

        let(:programmes) { [Programme.hpv, Programme.menacwy] }
        let(:session) { create(:session, team:, programmes: [Programme.hpv]) }

        it "has errors" do
          expect(immunisation_import_row).to be_invalid
          expect(immunisation_import_row.errors["PROGRAMME"]).to eq(
            ["This programme is not available in this session."]
          )
        end
      end

      context "vaccination in a session, no vaccinator details provided" do
        let(:data) do
          valid_data.except(
            "PERFORMING_PROFESSIONAL_EMAIL",
            "PERFORMING_PROFESSIONAL_FORENAME",
            "PERFORMING_PROFESSIONAL_SURNAME"
          ).merge(
            "DATE_OF_VACCINATION" => "#{AcademicYear.current}0901",
            "VACCINATED" => "Y",
            "SESSION_ID" => session.id.to_s
          )
        end

        let(:session) { create(:session, team:, programmes:) }

        it "has errors" do
          expect(immunisation_import_row).to be_invalid
          expect(immunisation_import_row.errors[:base]).to include(
            "<code>PERFORMING_PROFESSIONAL_EMAIL</code> is required"
          )
        end
      end

      context "vaccination in a session, vaccinator email not provided but forename and surname are" do
        let(:data) do
          valid_data.except("PERFORMING_PROFESSIONAL_EMAIL").merge(
            "PERFORMING_PROFESSIONAL_FORENAME" => "John",
            "PERFORMING_PROFESSIONAL_SURNAME" => "Smith",
            "DATE_OF_VACCINATION" => "#{AcademicYear.current}0901",
            "VACCINATED" => "Y",
            "SESSION_ID" => session.id.to_s
          )
        end

        let(:session) { create(:session, team:, programmes:) }

        it "has errors" do
          expect(immunisation_import_row).to be_invalid
          expect(immunisation_import_row.errors[:base]).to include(
            "<code>PERFORMING_PROFESSIONAL_EMAIL</code> is required"
          )
        end
      end

      context "vaccination in a MenACWY session and no dose sequence is provided" do
        let(:data) do
          {
            "SESSION_ID" => session.id.to_s,
            "PROGRAMME" => "MenACWY",
            "VACCINATED" => "Y"
          }
        end

        let(:programmes) { [Programme.menacwy] }
        let(:session) { create(:session, team:, programmes:) }

        it "has errors" do
          expect(immunisation_import_row).to be_invalid
          expect(immunisation_import_row.errors[:base]).to include(
            "<code>DOSE_SEQUENCE</code> or <code>Vaccination type</code> is required"
          )
        end
      end

      context "vaccination in a Td/IPV session and no dose sequence is provided" do
        let(:data) do
          {
            "SESSION_ID" => session.id.to_s,
            "PROGRAMME" => "3-in-1",
            "VACCINATED" => "Y"
          }
        end

        let(:programmes) { [Programme.td_ipv] }
        let(:session) { create(:session, team:, programmes:) }

        it "has errors" do
          expect(immunisation_import_row).to be_invalid
          expect(immunisation_import_row.errors[:base]).to include(
            "<code>DOSE_SEQUENCE</code> or <code>Vaccination type</code> is required"
          )
        end
      end

      context "vaccination in an MMR session and no dose sequence is provided" do
        let(:programmes) { [Programme.mmr] }
        let(:session) { create(:session, team:, programmes:) }

        let(:data) do
          {
            "SESSION_ID" => session.id.to_s,
            "PROGRAMME" => "MMR",
            "VACCINATED" => "Y"
          }
        end

        it "has errors" do
          expect(immunisation_import_row).to be_invalid
          expect(immunisation_import_row.errors[:base]).to include(
            "<code>DOSE_SEQUENCE</code> or <code>Vaccination type</code> is required"
          )
        end
      end

      context "HPV vaccination in previous academic year, no vaccinator details provided" do
        let(:programmes) { [Programme.hpv] }

        let(:data) do
          valid_hpv_data.except(
            "PERFORMING_PROFESSIONAL_EMAIL",
            "PERFORMING_PROFESSIONAL_FORENAME",
            "PERFORMING_PROFESSIONAL_SURNAME"
          ).merge("DATE_OF_VACCINATION" => "20220101")
        end

        it { should be_valid }
      end

      context "HPV vaccination in previous academic year, vaccinator email provided but doesn't exist" do
        let(:data) do
          valid_hpv_data.merge(
            "PERFORMING_PROFESSIONAL_EMAIL" => "non-existent@example.com",
            "DATE_OF_VACCINATION" => "20220101"
          )
        end

        it "has errors" do
          expect(immunisation_import_row).to be_invalid
          expect(
            immunisation_import_row.errors["PERFORMING_PROFESSIONAL_EMAIL"]
          ).to include("Enter a valid email address.")
        end
      end

      context "Flu vaccination in previous academic year" do
        let(:programmes) { [Programme.flu] }

        let(:data) { valid_flu_data.merge("DATE_OF_VACCINATION" => "20240101") }

        it "is invalid" do
          expect(immunisation_import_row).to be_invalid
          expect(
            immunisation_import_row.errors["DATE_OF_VACCINATION"]
          ).to contain_exactly("must be in the current academic year")
        end
      end

      context "Flu vaccination in previous academic year, no vaccinator details provided" do
        let(:programmes) { [Programme.flu] }

        let(:data) do
          valid_flu_data.except(
            "PERFORMING_PROFESSIONAL_EMAIL",
            "PERFORMING_PROFESSIONAL_FORENAME",
            "PERFORMING_PROFESSIONAL_SURNAME"
          ).merge("DATE_OF_VACCINATION" => "20220101")
        end

        it { should be_invalid }
      end

      context "vaccination in a session, with a delivery site that is not appropriate for HPV" do
        let(:programmes) { [Programme.hpv] }
        let(:session) { create(:session, team:, programmes:) }

        let(:data) do
          valid_hpv_data.merge(
            "ANATOMICAL_SITE" => "nasal",
            "VACCINATED" => "Y",
            "VACCINE_GIVEN" => "Gardasil9",
            "DATE_OF_VACCINATION" => "#{AcademicYear.current}0901",
            "SESSION_ID" => session.id.to_s
          )
        end

        it "has errors" do
          expect(immunisation_import_row).to be_invalid
          expect(immunisation_import_row.errors["ANATOMICAL_SITE"]).to eq(
            ["Enter a anatomical site that is appropriate for the vaccine."]
          )
        end
      end

      context "vaccination in a previous academic year, with a delivery site that's not appropriate for HPV" do
        let(:programmes) { [Programme.hpv] }

        let(:data) do
          {
            "ANATOMICAL_SITE" => "left buttock",
            "VACCINATED" => "Y",
            "VACCINE_GIVEN" => "Gardasil9",
            "DATE_OF_VACCINATION" => "20220101"
          }
        end

        it "raises no errors on delivery site to be more permissive of legacy records" do
          immunisation_import_row.valid?
          expect(immunisation_import_row.errors["ANATOMICAL_SITE"]).to be_empty
        end
      end

      context "vaccination in a session, with a delivery site that is not appropriate for flu" do
        let(:programmes) { [Programme.flu] }
        let(:session) { create(:session, team:, programmes:) }

        let(:data) do
          {
            "ANATOMICAL_SITE" => "left buttock",
            "VACCINATED" => "Y",
            "PROGRAMME" => "Flu",
            "VACCINE_GIVEN" => "AstraZeneca Fluenz",
            "DATE_OF_VACCINATION" => "#{AcademicYear.current}0901",
            "SESSION_ID" => session.id.to_s
          }
        end

        it "has errors" do
          expect(immunisation_import_row).to be_invalid
          expect(immunisation_import_row.errors["ANATOMICAL_SITE"]).to eq(
            ["Enter a anatomical site that is appropriate for the vaccine."]
          )
        end
      end

      context "vaccination in a session without a batch" do
        let(:programmes) { [Programme.flu] }

        let(:data) do
          {
            "VACCINATED" => "Y",
            "PROGRAMME" => "Flu",
            "DATE_OF_VACCINATION" => "#{AcademicYear.current}0901",
            "SESSION_ID" => session.id.to_s
          }
        end

        let(:session) { create(:session, team:, programmes:) }

        it "has errors" do
          expect(immunisation_import_row).to be_invalid
          expect(immunisation_import_row.errors[:base]).to include(
            "<code>BATCH_EXPIRY_DATE</code> is required"
          )
          expect(immunisation_import_row.errors[:base]).to include(
            "<code>BATCH_NUMBER</code> or <code>Vaccination batch number</code> is required"
          )
        end
      end

      context "vaccination in a session where name-like fields have length greater than 300" do
        let(:invalid_name_length) { "a" * 301 }
        let(:data) do
          {
            "VACCINATED" => "Y",
            "BATCH_NUMBER" => invalid_name_length,
            "CLINIC_NAME" => invalid_name_length,
            "PERSON_FORENAME" => invalid_name_length,
            "PERSON_SURNAME" => invalid_name_length,
            "SCHOOL_NAME" => invalid_name_length
          }
        end

        it "has errors" do
          expect(immunisation_import_row).to be_invalid

          expect(immunisation_import_row.errors["BATCH_NUMBER"]).to include(
            "must be at most 100 characters long"
          )
          expect(immunisation_import_row.errors["CLINIC_NAME"]).to include(
            "is greater than 300 characters long"
          )
          expect(immunisation_import_row.errors["PERSON_FORENAME"]).to include(
            "is greater than 300 characters long"
          )
          expect(immunisation_import_row.errors["PERSON_SURNAME"]).to include(
            "is greater than 300 characters long"
          )
          expect(immunisation_import_row.errors["SCHOOL_NAME"]).to include(
            "is greater than 300 characters long"
          )
        end
      end

      context "batch number fewer than 2 characters" do
        let(:data) { { "VACCINATED" => "Y", "BATCH_NUMBER" => "a" } }

        it "has errors" do
          expect(immunisation_import_row).to be_invalid

          expect(immunisation_import_row.errors["BATCH_NUMBER"]).to include(
            "must be at least 2 characters long"
          )
        end
      end

      context "vaccination in a session without a delivery site" do
        let(:programmes) { [Programme.flu] }

        let(:data) do
          {
            "VACCINATED" => "Y",
            "PROGRAMME" => "Flu",
            "DATE_OF_VACCINATION" => "#{AcademicYear.current}0901",
            "SESSION_ID" => session.id.to_s
          }
        end

        let(:session) { create(:session, team:, programmes:) }

        it "has errors" do
          expect(immunisation_import_row).to be_invalid
          expect(immunisation_import_row.errors[:base]).to include(
            "<code>ANATOMICAL_SITE</code> is required"
          )
        end
      end

      context "vaccination in a session, but UUID matches a record sourced from NHS immunisations API" do
        let(:data) do
          {
            "VACCINATED" => "Y",
            "PROGRAMME" => "Flu",
            "SESSION_ID" => 1,
            "DATE_OF_VACCINATION" => "#{AcademicYear.current}0901",
            "UUID" => "12345678-1234-1234-1234-123456789abc"
          }
        end

        before do
          create(
            :vaccination_record,
            programme: Programme.flu,
            uuid: "12345678-1234-1234-1234-123456789abc",
            source: :nhs_immunisations_api,
            nhs_immunisations_api_identifier_system: "ABC",
            nhs_immunisations_api_identifier_value: "123"
          )
        end

        it "has errors" do
          expect(immunisation_import_row).to be_invalid
          expect(immunisation_import_row.errors["SESSION_ID"]).to eq(
            [
              "A session ID cannot be provided for this record; " \
                "this record was sourced from an external source."
            ]
          )
        end
      end

      context "with valid fields for Flu" do
        let(:programmes) { [Programme.flu] }

        let(:data) { valid_flu_data }

        it { should be_valid }

        context "with a performing profession email provided as well" do
          before { data["PERFORMING_PROFESSIONAL_EMAIL"] = create(:user).email }

          it { should be_valid }

          it "ignores the performing professional fields" do
            immunisation_import_row.set_patient

            expect(
              immunisation_import_row.to_vaccination_record.performed_by_given_name
            ).to be_nil
            expect(
              immunisation_import_row.to_vaccination_record.performed_by_family_name
            ).to be_nil
          end
        end
      end

      context "with valid fields for HPV" do
        let(:programmes) { [Programme.hpv] }

        let(:data) { valid_hpv_data }

        it { should be_valid }
      end

      context "with case insensitive programme" do
        let(:data) { { "PROGRAMME" => "hpv" } }

        it "accepts the programme" do
          expect(immunisation_import_row).to be_invalid

          expect(immunisation_import_row.errors[:base]).not_to include(
            "<code>PROGRAMME</code> or <code>Vaccination type</code> is required"
          )
        end
      end

      context "with MMRV programme name" do
        let(:programmes) { [Programme.mmr] }
        let(:session) { create(:session, team:, programmes:) }
        let(:data) do
          valid_common_data.merge(
            "PROGRAMME" => "MMRV",
            "DATE_OF_VACCINATION" => "#{AcademicYear.current}0901"
          )
        end

        it "recognizes MMRV as MMR programme" do
          immunisation_import_row.set_patient

          expect(
            immunisation_import_row.to_vaccination_record&.programme
          ).to eq(Programme.mmr)
        end
      end
    end

    context "for a national reporting upload" do
      let(:programmes) { [Programme.hpv, Programme.flu] }

      let(:import_type) { "national_reporting" }

      shared_examples "with an empty row where vaccine was administered (both national reporting upload types)" do
        it "requires the mandatory fields" do
          expect(immunisation_import_row).to be_invalid
          expect(immunisation_import_row.errors[:base]).to include(
            "<code>DATE_OF_VACCINATION</code> is required",
            "<code>PERSON_DOB</code> is required",
            "<code>PERSON_FORENAME</code> is required",
            "<code>PERSON_GENDER_CODE</code> or <code>PERSON_GENDER</code> is required",
            "<code>PERSON_SURNAME</code> is required",
            "<code>PERSON_POSTCODE</code> is required",
            "<code>LOCAL_PATIENT_ID</code> is required",
            "<code>LOCAL_PATIENT_ID_URI</code> is required",
            "<code>ORGANISATION_CODE</code> is required",
            "<code>SCHOOL_URN</code> is required",
            "<code>ANATOMICAL_SITE</code> is required",
            "<code>BATCH_NUMBER</code> is required",
            "<code>BATCH_EXPIRY_DATE</code> is required"
          )
        end
      end

      shared_examples "when `VACCINATED` is `N`" do
        context "when `VACCINATED` is `N`" do
          let(:data) { { "VACCINATED" => "N" } }

          it "doesn't validate anything" do
            expect(immunisation_import_row).to be_valid
            expect(immunisation_import_row.errors[:base]).to eq []
          end
        end
      end

      shared_examples "it doesn't make `SCHOOL_NAME` compulsory" do
        context "when `SCHOOL_URN` is 888888" do
          let(:data) { { "SCHOOL_URN" => "888888" } }

          it "doesn't require SCHOOL_NAME" do
            expect(immunisation_import_row).to be_invalid
            expect(immunisation_import_row.errors[:base]).not_to include(
              "<code>SCHOOL_NAME</code> or <code>School</code> is required"
            )
          end
        end
      end

      shared_examples "when vaccinated date is in a previous academic year" do
        context "when vaccinated date is in a previous academic year"
        let(:data) do
          { "DATE_OF_VACCINATION" => "20220101", "VACCINATED" => "Y" }
        end

        it "is invalid" do
          expect(immunisation_import_row).to be_invalid
          expect(
            immunisation_import_row.errors[:DATE_OF_VACCINATION]
          ).to include("must be in the current academic year")
        end
      end

      shared_examples "when an NHS number is provided" do
        context "when an NHS number is provided" do
          let(:data) { { "NHS_NUMBER" => "1234567890", "VACCINATED" => "Y" } }

          it "still requires all the demographic information" do
            expect(immunisation_import_row).to be_invalid
            expect(immunisation_import_row.errors[:base]).to include(
              "<code>PERSON_DOB</code> is required",
              "<code>PERSON_FORENAME</code> is required",
              "<code>PERSON_GENDER_CODE</code> or <code>PERSON_GENDER</code> is required",
              "<code>PERSON_SURNAME</code> is required",
              "<code>PERSON_POSTCODE</code> is required"
            )
          end
        end
      end

      shared_examples "when Mavis columns are present, which the national reporting upload should ignore" do
        let(:data) do
          valid_national_reporting_flu_data.merge(
            {
              "PROGRAMME" => "HPV",
              "PERFORMING_PROFESSIONAL_EMAIL" => "abc123@example.com",
              "NOTES" => "Here are some notes",
              "CARE_SETTING" => 2,
              "CLINIC_NAME" => "The Hog's Head",
              "SESSION_ID" => 1,
              "UUID" => "ABCD1234-26cc-44e4-b886-c3cc90ba01b6",
              "REASON_NOT_VACCINATED" => "Unwell",
              "Vaccination type" => "HPV 1",
              "EVENT_LOCATION_TYPE" => "school",
              "SUPPLIER_EMAIL" => "abc@example.com"
            }
          )
        end

        it "ignores the Mavis columns" do
          expect(immunisation_import_row).to be_valid
        end
      end

      shared_context "when performed_at is before the team's cut off date" do
        context "when the team has a cut off date" do
          let(:team) do
            create(
              :team,
              :national_reporting,
              ods_code: "ABC",
              programmes:,
              national_reporting_cut_off_date: Date.new(2026, 2, 1)
            )
          end

          it "returns an error" do
            expect(immunisation_import_row).to be_invalid
            expect(
              immunisation_import_row.errors[:DATE_OF_VACCINATION]
            ).to include(
              "must be on or after your team's start date with Mavis national reporting: 1 February 2026"
            )
          end
        end

        context "when the team has no cut off date" do
          let(:team) do
            create(
              :team,
              :national_reporting,
              ods_code: "ABC",
              programmes:,
              national_reporting_cut_off_date: nil
            )
          end

          it "doesn't return an error" do
            expect(immunisation_import_row).to be_valid
          end
        end
      end

      context "of unknown type (no VACCINE_GIVEN)" do
        context "with an empty row" do
          let(:data) { {} }

          it "requires VACCINE_GIVEN" do
            expect(immunisation_import_row).to be_invalid
            expect(immunisation_import_row.errors[:base]).to include(
              "<code>VACCINE_GIVEN</code> is required"
            )
          end

          it "ensures that the similar Mavis error is not visible" do
            expect(immunisation_import_row).to be_invalid
            expect(immunisation_import_row.errors[:base]).not_to include(
              "<code>PROGRAMME</code> or <code>Vaccination type</code> is required"
            )
          end

          include_examples "when an NHS number is provided"

          include_examples "when vaccinated date is in a previous academic year"

          include_examples "it doesn't make `SCHOOL_NAME` compulsory"
        end

        include_examples "when `VACCINATED` is `N`"

        context "when `VACCINE_GIVEN` matches to an incorrect programme" do
          let(:programmes) { Programme.all }

          shared_examples "rejects a VACCINE_GIVEN" do |vaccine_given|
            context "with code: #{vaccine_given}" do
              let(:data) { { "VACCINE_GIVEN" => vaccine_given } }

              it "throws a validation error" do
                expect(immunisation_import_row).to be_invalid
                expect(
                  immunisation_import_row.errors[:VACCINE_GIVEN]
                ).to include(
                  "This vaccine programme is not accepted in this upload."
                )
              end
            end
          end

          include_examples "rejects a VACCINE_GIVEN", "MenQuadfi"
          include_examples "rejects a VACCINE_GIVEN", "Priorix"
          include_examples "rejects a VACCINE_GIVEN", "ProQuad"
          include_examples "rejects a VACCINE_GIVEN", "Revaxis"
        end
      end

      context "of type flu" do
        let(:basic_flu_data) do
          { "VACCINE_GIVEN" => "AstraZeneca Fluenz LAIV" }
        end

        shared_examples "it is equivalent to `VACCINATED` being `Y`" do
          include_examples "with an empty row where vaccine was administered (both national reporting upload types)"

          it "requires the mandatory fields specific to flu when vaccinated" do
            expect(immunisation_import_row).to be_invalid
            expect(immunisation_import_row.errors[:base]).to include(
              "<code>PERFORMING_PROFESSIONAL_FORENAME</code> is required",
              "<code>PERFORMING_PROFESSIONAL_SURNAME</code> is required"
            )
          end

          include_examples "it doesn't make `SCHOOL_NAME` compulsory"
        end

        context "with an empty row" do
          let(:data) { basic_flu_data }

          include_examples "it is equivalent to `VACCINATED` being `Y`"
        end

        context "with headers, but an empty row" do
          let(:data) do
            {
              "ORGANISATION_CODE" => "",
              "SCHOOL_NAME" => "",
              "SCHOOL_URN" => "",
              "NHS_NUMBER" => "",
              "PERSON_FORENAME" => "",
              "PERSON_SURNAME" => "",
              "PERSON_DOB" => "",
              "PERSON_POSTCODE" => "",
              "PERSON_GENDER_CODE" => "",
              "DATE_OF_VACCINATION" => "",
              "VACCINATED" => "",
              "PERFORMING_PROFESSIONAL_FORENAME" => "",
              "PERFORMING_PROFESSIONAL_SURNAME" => "",
              "VACCINE_GIVEN" => "",
              "ANATOMICAL_SITE" => "",
              "BATCH_EXPIRY_DATE" => "",
              "BATCH_NUMBER" => "",
              "LOCAL_PATIENT_ID" => "",
              "LOCAL_PATIENT_ID_URI" => ""
            }
          end

          it "has the correct errors" do
            expect(immunisation_import_row).to be_invalid

            expect(immunisation_import_row.errors.to_hash).to eq(
              {
                BATCH_EXPIRY_DATE: ["Enter a batch expiry date."],
                BATCH_NUMBER: ["Enter a batch number."],
                DATE_OF_VACCINATION: ["Enter a date."],
                ANATOMICAL_SITE: ["Enter an anatomical site."],
                LOCAL_PATIENT_ID: ["Enter a local patient ID."],
                LOCAL_PATIENT_ID_URI: ["Enter a local patient ID URI."],
                PERSON_DOB: ["Enter a date of birth."],
                PERSON_FORENAME: ["Enter a first name."],
                PERSON_GENDER_CODE: ["Enter a gender or gender code."],
                PERSON_SURNAME: ["Enter a last name."],
                PERSON_POSTCODE: ["Enter a valid postcode, such as SW1A 1AA."],
                ORGANISATION_CODE: ["Enter an organisation code."],
                SCHOOL_URN: ["Enter a school URN."],
                VACCINE_GIVEN: ["Enter a vaccine name."]
              }
            )
          end
        end

        context "when `VACCINATED` is `Y`" do
          let(:data) { basic_flu_data.merge({ "VACCINATED" => "Y" }) }

          include_examples "it is equivalent to `VACCINATED` being `Y`"
        end

        include_examples "when `VACCINATED` is `N`"

        include_examples "when Mavis columns are present, which the national reporting upload should ignore"

        context "when performed_at is after the team's cut off date" do
          let(:data) { valid_national_reporting_flu_data }

          include_examples "when performed_at is before the team's cut off date"
        end
      end

      context "of type hpv" do
        let(:basic_hpv_data) { { "VACCINE_GIVEN" => "Gardasil" } }

        shared_examples "it is equivalent to `VACCINATED` being `Y`" do
          include_examples "with an empty row where vaccine was administered (both national reporting upload types)"

          it "requires the mandatory fields specific to HPV" do
            expect(immunisation_import_row).to be_invalid
            expect(immunisation_import_row.errors[:base]).to include(
              "<code>DOSE_SEQUENCE</code> is required"
            )
          end

          include_examples "it doesn't make `SCHOOL_NAME` compulsory"
        end

        context "with an empty row" do
          let(:data) { basic_hpv_data }

          include_examples "it is equivalent to `VACCINATED` being `Y`"
        end

        context "when `VACCINATED` is `Y` (ie in all cases for HPV national reporting upload)" do
          let(:data) { basic_hpv_data.merge({ "VACCINATED" => "Y" }) }

          include_examples "it is equivalent to `VACCINATED` being `Y`"
        end

        include_examples "when `VACCINATED` is `N`"

        include_examples "when Mavis columns are present, which the national reporting upload should ignore"

        context "with an anatomical site which is not appropriate for the vaccine" do
          let(:data) { valid_hpv_data.merge("ANATOMICAL_SITE" => "nasal") }

          it "has errors" do
            expect(immunisation_import_row).to be_invalid
            expect(immunisation_import_row.errors["ANATOMICAL_SITE"]).to eq(
              ["Enter a anatomical site that is appropriate for the vaccine."]
            )
          end
        end

        context "when performed_at is after the team's cut off date" do
          let(:data) { valid_national_reporting_hpv_data }

          include_examples "when performed_at is before the team's cut off date"
        end
      end
    end
  end

  describe "#to_vaccination_record" do
    subject(:vaccination_record) do
      immunisation_import_row.set_patient(candidates: patients_batch)
      immunisation_import_row.to_vaccination_record
    end

    let(:patients_batch) { nil }

    shared_examples "with pseudo-postcodes" do
      ["ZZ99 3VZ", "ZZ99 3WZ", "ZZ99 3CZ"].each do |pseudo_postcode|
        context "when the postcode is #{pseudo_postcode}" do
          let(:address_postcode) { pseudo_postcode }

          it "assigns the postcode to the patient" do
            expect(vaccination_record.patient.address_postcode).to eq(
              pseudo_postcode
            )
          end
        end
      end
    end

    context "for a point_of_care upload" do
      let(:import_type) { "point_of_care" }
      let(:data) { valid_data }

      let(:not_vaccinated_data) do
        valid_data.merge(
          "VACCINATED" => "N",
          "BATCH_EXPIRY_DATE" => "",
          "BATCH_NUMBER" => "",
          "ANATOMICAL_SITE" => ""
        )
      end

      it { should be_administered }

      it "sets the administered at time" do
        expect(vaccination_record.performed_at).to eq(
          Time.new(2024, 1, 1, 0, 0, 0, "+00:00")
        )
      end

      context "with a daylight saving time date" do
        let(:data) { valid_data.merge("DATE_OF_VACCINATION" => "20230901") }

        it "sets the administered at time" do
          expect(vaccination_record.performed_at).to eq(Date.new(2023, 9, 1))
        end
      end

      context "with an Excel-exported-to-CSV date format" do
        let(:data) { valid_data.merge("DATE_OF_VACCINATION" => "01/09/2023") }

        it "parses the date and sets the administered at time" do
          expect(vaccination_record.performed_at).to eq(Date.new(2023, 9, 1))
        end
      end

      context "with an ISO 8601 date format" do
        let(:data) { valid_data.merge("DATE_OF_VACCINATION" => "2023-09-01") }

        it "parses the date and sets the administered at time" do
          expect(vaccination_record.performed_at).to eq(Date.new(2023, 9, 1))
        end
      end

      context "with a time of vaccination" do
        let(:data) { valid_data.merge("TIME_OF_VACCINATION" => "10:30:25") }

        it "sets the administered at time" do
          expect(vaccination_record.performed_at).to eq(
            Time.new(2024, 1, 1, 10, 30, 25, "+00:00")
          )
        end
      end

      context "with a time of vaccination without seconds" do
        let(:data) { valid_data.merge("TIME_OF_VACCINATION" => "1030") }

        it "sets the administered at time" do
          expect(vaccination_record.performed_at).to eq(
            Time.new(2024, 1, 1, 10, 30, 0, "+00:00")
          )
        end
      end

      context "with a daylight saving time" do
        let(:data) do
          valid_data.merge(
            "DATE_OF_VACCINATION" => "20230901",
            "TIME_OF_VACCINATION" => "1030"
          )
        end

        it "sets the administered at time" do
          expect(vaccination_record.performed_at).to eq(
            Time.new(2023, 9, 1, 10, 30, 0, "+01:00")
          )
        end
      end

      context "with the flu programme" do
        let(:programmes) { [Programme.flu] }

        let(:data) { valid_flu_data }

        it "has a vaccinator" do
          expect(vaccination_record.performed_by).to have_attributes(
            given_name: "John",
            family_name: "Smith"
          )
        end
      end

      context "without a vaccine with MMRV programme variant" do
        let(:programmes) { [Programme.mmr] }
        let(:data) do
          valid_data.except("VACCINE_GIVEN").merge("PROGRAMME" => "MMRV")
        end

        it "has the MMRV disease types" do
          expect(vaccination_record.disease_types).to eq(
            %w[measles mumps rubella varicella]
          )
        end
      end

      it "sets the disease types of the vaccine" do
        expect(vaccination_record.disease_types).to eq(
          Vaccine.find_by!(brand: "Gardasil 9").disease_types
        )
      end

      context "without a vaccine" do
        let(:data) { valid_data.except("VACCINE_GIVEN") }

        it "doesn't set a vaccine" do
          expect(vaccination_record.vaccine).to be_nil
        end

        it "does set a programme" do
          expect(vaccination_record.programme).not_to be_nil
        end

        it "sets the disease types of the programme" do
          expect(vaccination_record.disease_types).to eq(
            programmes.first.disease_types
          )
        end
      end

      context "with an existing vaccination record with the same UUID" do
        let!(:existing_vaccination_record) do
          create(
            :vaccination_record,
            programme: programmes.first,
            session: create(:session, team:, programmes:)
          )
        end

        let(:data) do
          valid_data.merge("UUID" => existing_vaccination_record.uuid)
        end

        it { should_not be_nil }
        it { should eq(existing_vaccination_record) }

        context "and the record has been previously discarded" do
          before { existing_vaccination_record.discard! }

          it "stages changes discarded at to nil" do
            expect(vaccination_record.pending_changes["discarded_at"]).to be_nil
          end
        end
      end

      context "with an existing vaccination record with the same programme and date" do
        let(:vaccine) { Vaccine.find_by!(upload_name: "Gardasil9") }
        let(:patient) do
          create(
            :patient,
            given_name:,
            family_name:,
            date_of_birth: Date.parse(date_of_birth),
            address_postcode:,
            nhs_number:
          )
        end

        let!(:existing_vaccination_record) do
          create(
            :vaccination_record,
            location_name: "Waterloo Road",
            patient:,
            performed_at: Time.zone.local(2024, 1, 1, 12, 30),
            performed_by_user: nil,
            performed_ods_code: "ABC",
            programme: programmes.first,
            vaccine:
          )
        end

        let(:data) { valid_data }

        it { should_not be_nil }
        it { should eq(existing_vaccination_record) }
      end

      describe "#batch_number" do
        subject(:batch_number) { vaccination_record.batch_number }

        let(:data) { valid_data }

        it { should eq("123") }
      end

      describe "#batch_expiry" do
        subject(:batch_expiry) { vaccination_record.batch_expiry }

        let(:data) { valid_data }

        it { should eq(Date.new(2021, 1, 1)) }
      end

      describe "#delivery_method" do
        subject { vaccination_record.delivery_method }

        context "with a nasal anatomical site" do
          let(:data) { valid_data.merge("ANATOMICAL_SITE" => "nasal") }

          it { should eq("nasal_spray") }
        end

        context "with a non-nasal anatomical site" do
          let(:data) { valid_data.merge("ANATOMICAL_SITE" => "left thigh") }

          it { should eq("intramuscular") }
        end
      end

      describe "#delivery_site" do
        subject { vaccination_record.delivery_site }

        shared_examples "an anatomical site" do |upload_value, delivery_site|
          context "with ANATOMICAL_SITE: #{upload_value}" do
            let(:data) { valid_data.merge("ANATOMICAL_SITE" => upload_value) }

            it "is valid" do
              expect(vaccination_record).to be_valid
            end

            it { should eq(delivery_site) }
          end
        end

        include_examples "an anatomical site", "left thigh", "left_thigh"
        include_examples "an anatomical site", "right thigh", "right_thigh"
        include_examples "an anatomical site",
                         "left upper arm",
                         "left_arm_upper_position"
        include_examples "an anatomical site",
                         "left deltoid",
                         "left_arm_upper_position"
        include_examples "an anatomical site",
                         "left arm (upper position)",
                         "left_arm_upper_position"
        include_examples "an anatomical site",
                         "left arm (lower position)",
                         "left_arm_lower_position"
        include_examples "an anatomical site",
                         "Left Lower",
                         "left_arm_lower_position"
        include_examples "an anatomical site",
                         "Left lower arm",
                         "left_arm_lower_position"
        include_examples "an anatomical site",
                         "right upper arm",
                         "right_arm_upper_position"
        include_examples "an anatomical site",
                         "right deltoid",
                         "right_arm_upper_position"
        include_examples "an anatomical site",
                         "right arm (upper position)",
                         "right_arm_upper_position"
        include_examples "an anatomical site",
                         "right arm (lower position)",
                         "right_arm_lower_position"
        include_examples "an anatomical site",
                         "Right Lower",
                         "right_arm_lower_position"
        include_examples "an anatomical site",
                         "Right lower arm",
                         "right_arm_lower_position"
        include_examples "an anatomical site", "left buttock", "left_buttock"
        include_examples "an anatomical site", "right buttock", "right_buttock"
        include_examples "an anatomical site", "nasal", "nose"
      end

      describe "#dose_sequence" do
        subject { vaccination_record.dose_sequence }

        context "without a value and for HPV" do
          let(:programmes) { [Programme.hpv] }

          let(:data) do
            valid_data.merge(
              "PROGRAMME" => "HPV",
              "VACCINE_GIVEN" => "Gardasil9",
              "DOSE_SEQUENCE" => ""
            )
          end

          it { should eq(1) }
        end

        context "without a value and for Td/IPV" do
          let(:programmes) { [Programme.td_ipv] }

          let(:data) do
            valid_data.merge(
              "PROGRAMME" => "3-in-1",
              "VACCINE_GIVEN" => "Revaxis",
              "DOSE_SEQUENCE" => ""
            )
          end

          it { should be_nil }
        end

        context "without a value and for MenACWY" do
          let(:programmes) { [Programme.menacwy] }

          let(:data) do
            valid_data.merge(
              "PROGRAMME" => "MenACWY",
              "VACCINE_GIVEN" => "MenQuadfi",
              "DOSE_SEQUENCE" => ""
            )
          end

          it { should be_nil }
        end

        context "with an invalid value" do
          let(:programmes) { [Programme.hpv] }

          let(:data) do
            valid_data.merge(
              "PROGRAMME" => "HPV",
              "VACCINE_GIVEN" => "Gardasil9",
              "DOSE_SEQUENCE" => "abc"
            )
          end

          it { expect(immunisation_import_row).to be_invalid }
        end

        context "with an invalid value and no programme" do
          let(:programmes) { [Programme.hpv] }

          let(:data) do
            valid_data.merge(
              "PROGRAMME" => "Unknown",
              "VACCINE_GIVEN" => "Unknown",
              "DOSE_SEQUENCE" => "abc"
            )
          end

          it "has errors about the programme but not the dose sequence" do
            expect(immunisation_import_row).to be_invalid
            expect(immunisation_import_row.errors["PROGRAMME"]).to eq(
              ["This programme is not recognised."]
            )
            expect(immunisation_import_row.errors["DOSE_SEQUENCE"]).to be_empty
          end
        end

        context "with a valid value" do
          let(:programmes) { [Programme.hpv] }

          let(:data) do
            valid_data.merge(
              "PROGRAMME" => "HPV",
              "VACCINE_GIVEN" => "Gardasil9",
              "DOSE_SEQUENCE" => "1"
            )
          end

          it { should eq(1) }
        end

        %w[1P 2P 3P].each_with_index do |value, index|
          context "with an HPV special value of #{value}" do
            let(:programmes) { [Programme.hpv] }

            let(:data) do
              valid_data.merge(
                "PROGRAMME" => "HPV",
                "VACCINE_GIVEN" => "Gardasil9",
                "DOSE_SEQUENCE" => value
              )
            end

            it { should eq(index + 1) }
          end
        end

        %w[1P 1B 2B].each_with_index do |value, index|
          context "with a MenACWY special value of #{value}" do
            let(:programmes) { [Programme.menacwy] }

            let(:data) do
              valid_data.merge(
                "PROGRAMME" => "MenACWY",
                "VACCINE_GIVEN" => "MenQuadfi",
                "DOSE_SEQUENCE" => value
              )
            end

            it { should eq(index + 1) }
          end
        end

        %w[1P 1B].each_with_index do |value, index|
          context "with an MMR special value of #{value}" do
            let(:programmes) { [Programme.mmr] }

            let(:data) do
              valid_data.merge(
                "PROGRAMME" => "MMR",
                "VACCINE_GIVEN" => "Priorix",
                "DOSE_SEQUENCE" => value
              )
            end

            it { should eq(index + 1) }
          end
        end

        %w[1P 2P 3P 1B 2B].each_with_index do |value, index|
          context "with a Td/IPV special value of #{value}" do
            let(:programmes) { [Programme.td_ipv] }

            let(:data) do
              valid_data.merge(
                "PROGRAMME" => "Td/IPV",
                "VACCINE_GIVEN" => "Revaxis",
                "DOSE_SEQUENCE" => value
              )
            end

            it { should eq(index + 1) }
          end
        end
      end

      describe "#location_name" do
        subject { vaccination_record.location_name }

        let(:valid_data) { valid_hpv_data.except("CARE_SETTING") }

        context "with a school session that exists" do
          let(:data) do
            valid_data.merge(
              "DATE_OF_VACCINATION" => session.dates.first.strftime("%Y%m%d"),
              "SESSION_ID" => session.id.to_s,
              "ORGANISATION_CODE" => team.organisation.ods_code,
              "PERFORMING_PROFESSIONAL_EMAIL" => create(:user).email,
              "DOSE_SEQUENCE" => "1"
            )
          end

          let(:session) { create(:session, team:, location:, programmes:) }

          it { should be_nil }
        end

        context "with a clinic session" do
          let(:data) do
            valid_data.merge(
              "DATE_OF_VACCINATION" => Date.current.strftime("%Y%m%d"),
              "SESSION_ID" => "clinic",
              "ORGANISATION_CODE" => team.organisation.ods_code,
              "PERFORMING_PROFESSIONAL_EMAIL" => create(:user).email,
              "DOSE_SEQUENCE" => "1"
            )
          end

          it { should eq("Waterloo Road") }
        end

        context "without a school URN" do
          let(:data) { valid_data.merge("SCHOOL_NAME" => "Waterloo Road") }

          it { should eq("Waterloo Road") }
        end

        context "without a school URN and a clinic exists" do
          let(:data) { valid_data.merge("SCHOOL_NAME" => "Waterloo Road") }

          before { create(:community_clinic, urn: nil) }

          it { should eq("Waterloo Road") }
        end

        context "with a known school and unknown care setting" do
          let(:data) do
            valid_data.merge(
              "SCHOOL_URN" => "123456",
              "SCHOOL_NAME" => "Waterloo Road"
            )
          end

          it { should eq("Waterloo Road") }
        end

        context "with a known school and no school name" do
          let(:data) { valid_data.merge("SCHOOL_URN" => "123456") }

          it { should eq("Waterloo Road") }
        end

        context "with a known school and community care setting" do
          let(:data) do
            valid_data.merge(
              "SCHOOL_URN" => "123456",
              "SCHOOL_NAME" => "Waterloo Road",
              "CARE_SETTING" => "2"
            )
          end

          it { should eq("Unknown") }
        end

        context "with a known school and community location type" do
          let(:data) do
            valid_data.merge(
              "SCHOOL_URN" => "123456",
              "SCHOOL_NAME" => "Waterloo Road",
              "Event Location Type" => "Hospital"
            )
          end

          it { should eq("Unknown") }
        end

        context "when home educated and community care setting" do
          let(:data) do
            valid_data.merge(
              "SCHOOL_URN" => "999999",
              "SCHOOL_NAME" => "",
              "CARE_SETTING" => "2"
            )
          end

          it { should eq("Unknown") }
        end

        context "when home educated and community care setting and a named clinic" do
          let(:data) do
            valid_data.merge(
              "SCHOOL_URN" => "999999",
              "SCHOOL_NAME" => "",
              "CARE_SETTING" => "2",
              "CLINIC_NAME" => "A Clinic"
            )
          end

          it { should eq("A Clinic") }
        end

        context "when home educated and community location type and a named clinic" do
          let(:data) do
            valid_data.merge(
              "School Code" => "999999",
              "School" => "",
              "Event Location Type" => "Clinic",
              "Event Done At" => "A Clinic"
            )
          end

          it { should eq("A Clinic") }
        end

        context "when home educated and unknown care setting" do
          let(:data) do
            valid_data.merge("SCHOOL_URN" => "999999", "SCHOOL_NAME" => nil)
          end

          it { should eq("Unknown") }
        end

        context "when home educated and unknown care setting and a named clinic" do
          let(:data) do
            valid_data.merge(
              "SCHOOL_URN" => "999999",
              "SCHOOL_NAME" => "",
              "CLINIC_NAME" => "A Clinic"
            )
          end

          it { should eq("A Clinic") }
        end

        context "with an unknown school and school care setting" do
          let(:data) do
            valid_data.merge(
              "SCHOOL_URN" => "888888",
              "SCHOOL_NAME" => "Waterloo Road",
              "CARE_SETTING" => "1"
            )
          end

          it { should eq("Waterloo Road") }
        end

        context "with an unknown school and school care setting and a clinic name" do
          let(:data) do
            valid_data.merge(
              "SCHOOL_URN" => "888888",
              "SCHOOL_NAME" => "Waterloo Road",
              "CARE_SETTING" => "1",
              "CLINIC_NAME" => "A Clinic"
            )
          end

          it { should eq("Waterloo Road") }
        end

        context "with an unknown school and community care setting" do
          let(:data) do
            valid_data.merge(
              "SCHOOL_URN" => "888888",
              "SCHOOL_NAME" => "Waterloo Road",
              "CARE_SETTING" => "2"
            )
          end

          it { should eq("Unknown") }
        end

        context "with an unknown school and community care setting and a clinic name" do
          let(:data) do
            valid_data.merge(
              "SCHOOL_URN" => "888888",
              "SCHOOL_NAME" => "Waterloo Road",
              "CARE_SETTING" => "2",
              "CLINIC_NAME" => "A Clinic"
            )
          end

          it { should eq("A Clinic") }
        end

        context "with an unknown school and unknown care setting" do
          let(:data) do
            valid_data.merge(
              "SCHOOL_URN" => "888888",
              "SCHOOL_NAME" => "Waterloo Road"
            )
          end

          it { should eq("Waterloo Road") }
        end

        context "with an unknown school and unknown care setting and a clinic name" do
          let(:data) do
            valid_data.merge(
              "SCHOOL_URN" => "888888",
              "SCHOOL_NAME" => "Waterloo Road",
              "CLINIC_NAME" => "A Clinic"
            )
          end

          it { should eq("A Clinic") }
        end
      end

      describe "#notes" do
        subject { vaccination_record.notes }

        context "without notes" do
          let(:data) { valid_data }

          it { should be_nil }
        end

        context "with notes" do
          let(:data) { valid_data.merge("NOTES" => "Some notes.") }

          it { should eq("Some notes.") }
        end
      end

      describe "#outcome" do
        subject { vaccination_record.outcome }

        let(:data) { valid_data }

        let(:not_vaccinated_data) do
          valid_data.merge(
            "VACCINATED" => "N",
            "BATCH_EXPIRY_DATE" => "",
            "BATCH_NUMBER" => "",
            "ANATOMICAL_SITE" => ""
          )
        end

        it { should eq("administered") }

        context "with positive short vaccinated value" do
          let(:data) { valid_data.merge("VACCINATED" => "Y") }

          it { should eq("administered") }
        end

        context "with positive long vaccinated value" do
          let(:data) { valid_data.merge("VACCINATED" => "Yes") }

          it { should eq("administered") }
        end

        {
          "refused" => "refused",
          "unwell" => "unwell",
          "vaccination contraindicated" => "contraindicated",
          "already had elsewhere" => "already_had"
        }.each do |input_reason, expected_enum|
          context "with reason '#{input_reason}'" do
            let(:data) do
              not_vaccinated_data.merge("REASON_NOT_VACCINATED" => input_reason)
            end

            it { should eq(expected_enum) }
          end
        end
      end

      describe "#patient" do
        subject(:patient) do
          immunisation_import_row.set_patient
          vaccination_record.patient
        end

        context "with new patient data" do
          let(:data) { valid_data }

          it { should_not be_nil }
        end

        context "matching logic" do
          context "with a brand new patient" do
            its(:given_name) { should eq given_name }
            its(:family_name) { should eq family_name }
            its(:date_of_birth) { should eq Date.parse(date_of_birth) }
            its(:address_postcode) { should eq address_postcode }

            it "doesn't add a patient to the database" do
              expect { patient }.not_to change(Patient, :count)
            end

            it "creates a new patient in memory" do
              expect(patient).to be_new_record
            end
          end

          context "with an existing patient matching NHS number" do
            let(:data) { valid_data }

            let!(:other_patient) { create(:patient, nhs_number:) }

            it { should eq(other_patient) }

            it "returns a record in the database" do
              expect(patient).not_to be_new_record
            end
          end

          context "with an existing matching patient without NHS number" do
            let(:data) { valid_data.except("NHS_NUMBER") }

            let!(:other_patient) do
              create(
                :patient,
                nhs_number:,
                given_name:,
                family_name:,
                address_postcode:,
                date_of_birth: Date.parse(date_of_birth)
              )
            end

            it { should eq(other_patient) }

            it "returns a record in the database" do
              expect(patient).not_to be_new_record
            end
          end

          context "without an NHS number and a 3 out of 4 match" do
            let(:data) { valid_data.except("NHS_NUMBER") }

            context "with an existing patient matching first name, last name and date of birth" do
              let(:other_patient) do
                create(
                  :patient,
                  given_name:,
                  family_name:,
                  nhs_number:,
                  date_of_birth: Date.parse(date_of_birth)
                )
              end

              it { should_not eq(other_patient) }

              it "creates a new patient in memory" do
                expect(patient).to be_new_record
                expect(patient).not_to be(other_patient)
              end
            end

            context "with an existing patient matching first name, last name and postcode" do
              let(:data) { valid_data.except("NHS_NUMBER") }

              let(:other_patient) do
                create(
                  :patient,
                  given_name:,
                  family_name:,
                  address_postcode:,
                  nhs_number:
                )
              end

              it { should_not eq(other_patient) }

              it "returns a record in the database" do
                expect(patient).to be_new_record
              end
            end

            context "with an existing patient matching first name, date of birth and postcode" do
              let(:data) { valid_data.except("NHS_NUMBER") }

              let(:other_patient) do
                create(
                  :patient,
                  given_name:,
                  date_of_birth: Date.parse(date_of_birth),
                  address_postcode:,
                  nhs_number:
                )
              end

              it { should_not eq(other_patient) }

              it "returns a record in the database" do
                expect(patient).to be_new_record
              end
            end

            context "with an existing patient matching last name, date of birth and postcode (a twin)" do
              # This is a twin
              let(:data) { valid_data.except("NHS_NUMBER") }

              let!(:other_patient) do
                create(
                  :patient,
                  given_name: "James",
                  family_name:,
                  date_of_birth: Date.parse(date_of_birth),
                  address_postcode:,
                  nhs_number:
                )
              end

              it { should_not eq(other_patient) }

              it "returns a record in the database" do
                expect(patient).to be_new_record
              end
            end

            context "with both twin patients existing" do
              let!(:other_patient) do
                create(
                  :patient,
                  given_name: "James",
                  family_name:,
                  address_postcode:,
                  date_of_birth: Date.parse(date_of_birth)
                )
              end

              let!(:matching_patient) do
                create(
                  :patient,
                  given_name:,
                  family_name:,
                  address_postcode:,
                  date_of_birth: Date.parse(date_of_birth)
                )
              end

              its(:given_name) { should eq given_name }
              it { should_not eq other_patient }
              it { should eq matching_patient }
            end

            context "with both twin patients existing, where none have NHS numbers" do
              before do
                create(
                  :patient,
                  nhs_number: nil,
                  given_name: "James",
                  family_name:,
                  address_postcode:,
                  date_of_birth: Date.parse(date_of_birth)
                )
              end

              let!(:existing_patient) do
                create(
                  :patient,
                  nhs_number: nil,
                  given_name:,
                  family_name:,
                  address_postcode:,
                  date_of_birth: Date.parse(date_of_birth)
                )
              end

              its(:given_name) { should eq given_name }
              it { should eq existing_patient }
            end
          end

          context "with an existing matching patient but different patient data" do
            let(:data) { valid_data }

            it "does not stage any changes as vaccs history data is potentially out of date" do
              create(:patient, nhs_number:, address_postcode: "CB1 1AA")
              expect(patient.pending_changes).to be_empty
            end
          end

          context "with an existing matching patient but mismatching capitalisation, without NHS number" do
            let(:data) do
              valid_data.except("NHS_NUMBER").merge(
                "PERSON_FORENAME" => "RON",
                "PERSON_SURNAME" => "WEASLEY",
                "PERSON_POSTCODE" => "sw1a 1aa"
              )
            end

            let!(:existing_patient) do
              create(
                :patient,
                given_name: "Ron",
                family_name: "Weasley",
                date_of_birth: Date.parse(date_of_birth),
                address_postcode:,
                nhs_number: "9990000018"
              )
            end

            it "still matches to a patient" do
              expect(patient).to eq(existing_patient)
            end
          end

          context "with a patient in the patients_batch" do
            let(:data) { valid_data }

            let(:existing_patient) do
              build(
                :patient,
                nhs_number:,
                given_name:,
                family_name:,
                address_postcode:,
                date_of_birth: Date.parse(date_of_birth)
              )
            end

            let(:patients_batch) { [existing_patient] }

            it "matches to the patient in the patients_batch" do
              expect(patient).to eq(existing_patient)
            end
          end
        end

        describe "#address_postcode" do
          subject { patient.address_postcode }

          context "with a valid postcode" do
            let(:data) { valid_data.merge("PERSON_POSTCODE" => "SW1 1AA") }

            it { should eq("SW1 1AA") }
          end

          context "with a valid unformatted postcode" do
            let(:data) { valid_data.merge("PERSON_POSTCODE" => "sw11aa") }

            it { should eq("SW1 1AA") }
          end
        end

        describe "#date_of_birth" do
          subject { patient.date_of_birth }

          context "with a YYYYMMDD value" do
            let(:data) { valid_data.merge("PERSON_DOB" => "20230901") }

            it { should eq(Date.new(2023, 9, 1)) }
          end

          context "with an Excel-exported-to-CSV date format" do
            let(:data) { valid_data.merge("PERSON_DOB" => "01/09/2023") }

            it { should eq(Date.new(2023, 9, 1)) }
          end
        end

        describe "#gender_code" do
          subject { patient.gender_code }

          let(:valid_data_without_gender) do
            valid_data.except("PERSON_GENDER_CODE")
          end

          shared_examples "with a value" do |key|
            context "with a 'unknown' value" do
              let(:data) { valid_data_without_gender.merge(key => "Unknown") }

              it { should eq("not_known") }
            end

            context "with a 'indeterminate' value" do
              let(:data) do
                valid_data_without_gender.merge(key => "Indeterminate")
              end

              it { should eq("not_known") }
            end

            context "with a 'not known' value" do
              let(:data) { valid_data_without_gender.merge(key => "Not Known") }

              it { should eq("not_known") }
            end

            context "with a 'male' value" do
              let(:data) { valid_data_without_gender.merge(key => "Male") }

              it { should eq("male") }
            end

            context "with a 'female' value" do
              let(:data) { valid_data_without_gender.merge(key => "Female") }

              it { should eq("female") }
            end

            context "with a 'not specified' value" do
              let(:data) do
                valid_data_without_gender.merge(key => "Not Specified")
              end

              it { should eq("not_specified") }
            end
          end

          include_examples "with a value", "PERSON_GENDER_CODE"
          include_examples "with a value", "PERSON_GENDER"
          include_examples "with a value", "Sex"
        end
      end

      describe "#performed_at" do
        subject { vaccination_record.performed_at }

        let(:year) { 2024 }
        let(:month) { 1 }
        let(:day) { 1 }

        context "with a HH:MM:SS value" do
          let(:data) { valid_data.merge("TIME_OF_VACCINATION" => "10:15:30") }

          it { should eq(Time.zone.local(year, month, day, 10, 15, 30)) }
        end

        context "with a HHMMSS value" do
          let(:data) { valid_data.merge("TIME_OF_VACCINATION" => "101530") }

          it { should eq(Time.zone.local(year, month, day, 10, 15, 30)) }
        end

        context "with a HH:MM value" do
          let(:data) { valid_data.merge("TIME_OF_VACCINATION" => "10:15") }

          it { should eq(Time.zone.local(year, month, day, 10, 15, 0)) }
        end

        context "with a HHMM value" do
          let(:data) { valid_data.merge("TIME_OF_VACCINATION" => "1015") }

          it { should eq(Time.zone.local(year, month, day, 10, 15, 0)) }
        end

        context "with a HH value" do
          let(:data) { valid_data.merge("TIME_OF_VACCINATION" => "10") }

          it { should eq(Time.zone.local(year, month, day, 10, 0, 0)) }
        end
      end

      describe "#performed_by_user" do
        subject { vaccination_record.performed_by_user }

        context "with a value" do
          let(:data) do
            valid_data.merge(
              "PERFORMING_PROFESSIONAL_EMAIL" => "nurse@example.com"
            )
          end

          context "and a user that doesn't exist" do
            it { expect(immunisation_import_row).to be_invalid }
          end

          context "and a user that does exist" do
            let!(:user) { create(:user, email: "nurse@example.com") }

            it { should eq(user) }
          end
        end
      end

      describe "#supplied_by" do
        subject { vaccination_record.supplied_by }

        context "with a value" do
          let(:data) do
            valid_data.merge("SUPPLIER_EMAIL" => "nurse@example.com")
          end

          context "and a user that doesn't exist" do
            it { expect(immunisation_import_row).to be_invalid }
          end

          context "and a user that does exist" do
            let!(:user) { create(:nurse, email: "nurse@example.com") }

            it { should eq(user) }
          end
        end
      end

      describe "#performed_ods_code" do
        subject { vaccination_record.performed_ods_code }

        context "with a value" do
          let(:data) { valid_data.merge("ORGANISATION_CODE" => "ABC") }

          it { should eq("ABC") }
        end
      end

      describe "#programme" do
        subject { vaccination_record.programme }

        context "with a value with exact capitalisation" do
          let(:data) do
            valid_data.merge("PROGRAMME" => "HPV", "VACCINE_GIVEN" => nil)
          end

          it { should eq Programme.hpv }
        end

        context "with a value with mismatching capitalisation" do
          let(:data) do
            valid_data.merge("PROGRAMME" => "hpv", "VACCINE_GIVEN" => nil)
          end

          it { should eq Programme.hpv }
        end
      end

      describe "#protocol" do
        subject { vaccination_record.protocol }

        it { should eq("pgd") }

        context "with a supplier" do
          before { create(:nurse, email: "nurse@example.com") }

          let(:data) do
            valid_data.merge("SUPPLIER_EMAIL" => "nurse@example.com")
          end

          it { should eq("national") }

          context "and nasal flu PSD" do
            let(:programmes) { [Programme.flu] }
            let(:data) do
              valid_flu_data.merge("SUPPLIER_EMAIL" => "nurse@example.com")
            end

            let!(:patient) { create(:patient, nhs_number:) }

            before do
              create(
                :patient_specific_direction,
                patient:,
                programme: programmes.first
              )
            end

            it { should eq("psd") }
          end

          context "and nasal flu PGD" do
            let(:programmes) { [Programme.flu] }
            let(:data) do
              valid_flu_data.merge("SUPPLIER_EMAIL" => "nurse@example.com")
            end

            it { should eq("pgd") }
          end
        end
      end

      describe "#source" do
        context "with a historical record" do
          its(:source) { should eq "historical_upload" }
        end

        context "with an offline spreadsheet" do
          let(:data) do
            valid_data.merge(
              "DATE_OF_VACCINATION" => session.dates.first.strftime("%Y%m%d"),
              "SESSION_ID" => session.id.to_s,
              "ORGANISATION_CODE" => team.organisation.ods_code,
              "PERFORMING_PROFESSIONAL_EMAIL" => create(:user).email,
              "DOSE_SEQUENCE" => "1"
            )
          end

          let(:session) { create(:session, team:, programmes:) }

          its(:source) { should eq "service" }
        end
      end

      context "without an expiry date" do
        let(:data) { valid_data.merge("BATCH_EXPIRY_DATE" => "") }

        it { should_not be_nil }
      end

      include_examples "with pseudo-postcodes"

      context "when national reporting columns are present, which the Mavis upload should ignore" do
        let(:data) do
          valid_data.merge(
            {
              "LOCAL_PATIENT_ID" => "CIN-OXFORD-pat123456",
              "LOCAL_PATIENT_ID_URI" => "https://cinnamon.nhs.uk/0de/system1"
            }
          )
        end

        it "creates a valid vaccination record" do
          expect(vaccination_record).to be_valid
        end

        its(:local_patient_id) { should be_nil }
        its(:local_patient_id_uri) { should be_nil }
      end

      context "ignore duplicate vaccination records with missing site if other attributes are unchanged" do
        let!(:existing_vaccination_record) do
          create(
            :vaccination_record,
            team:,
            programme: programmes.first,
            location: nil,
            location_name: location.name,
            performed_by_user: nil,
            performed_at_date: valid_hpv_data["DATE_OF_VACCINATION"],
            performed_at_time: nil,
            source: :nhs_immunisations_api,
            nhs_immunisations_api_identifier_system: "ABC",
            nhs_immunisations_api_identifier_value: "123",
            protocol: nil,
            delivery_site: existing_delivery_site,
            delivery_method: existing_delivery_method,
            batch_number: nil,
            batch_expiry: nil
          )
        end

        let(:duplicate_hpv_data) do
          valid_hpv_data.merge(
            "UUID" => existing_vaccination_record.uuid,
            "PERSON_FORENAME" => existing_vaccination_record.patient.given_name,
            "PERSON_SURNAME" => existing_vaccination_record.patient.family_name,
            "PERSON_DOB" =>
              existing_vaccination_record.patient.date_of_birth.to_s,
            "NHS_NUMBER" => existing_vaccination_record.patient.nhs_number,
            "PERSON_POSTCODE" =>
              existing_vaccination_record.patient.address_postcode,
            "BATCH_EXPIRY_DATE" => nil,
            "BATCH_NUMBER" => nil,
            "VACCINE_GIVEN" => nil,
            "ORGANISATION_CODE" =>
              existing_vaccination_record.performed_ods_code
          )
        end

        context "in first import site defined and in second missing" do
          let(:existing_delivery_site) { "left_arm_upper_position" }
          let(:existing_delivery_method) { "intramuscular" }

          let(:data) { duplicate_hpv_data.merge("ANATOMICAL_SITE" => nil) }

          it { should eq(existing_vaccination_record) }

          it "identifies pending changes" do
            expect(vaccination_record.pending_changes?).to be(false)
          end
        end

        context "in first import site missing and in second defined" do
          let(:existing_delivery_site) { nil }
          let(:existing_delivery_method) { nil }

          let(:data) { duplicate_hpv_data }

          it { should eq(existing_vaccination_record) }

          it "identifies pending changes" do
            expect(vaccination_record.pending_changes?).to be(false)
          end
        end

        context "in first import site defined and in second missing but dose sequence changed" do
          let(:existing_delivery_site) { "left_arm_upper_position" }
          let(:existing_delivery_method) { "intramuscular" }

          let(:data) do
            duplicate_hpv_data.merge(
              "ANATOMICAL_SITE" => nil,
              "DOSE_SEQUENCE" => "2"
            )
          end

          it "identifies pending changes" do
            expect(vaccination_record.pending_changes.length).to eq(3)
          end
        end
      end
    end

    context "for a national reporting upload" do
      let(:programmes) { [Programme.hpv, Programme.flu] }

      let(:import_type) { "national_reporting" }

      shared_examples "date deduplication with existing vaccination records" do |programme|
        let(:patient) { create(:patient, nhs_number:) }

        let(:other_vaccination_record) do
          create(:vaccination_record, patient:, programme:, performed_at:)
        end

        context "with an existing vaccination record in a different academic year" do
          let(:performed_at) { Time.zone.local(2023, 1, 1, 13, 10, 4) }

          before { other_vaccination_record }

          it { should_not be_nil }
          it { should_not eq other_vaccination_record }
          its(:pending_changes) { should be_empty }
        end

        context "with an existing vaccination record on a different date in the same academic year" do
          let(:performed_at) { Time.zone.local(2026, 1, 1, 12, 10, 2) }

          before { other_vaccination_record }

          it { should_not be_nil }
          it { should_not eq other_vaccination_record }
          its(:pending_changes) { should be_empty }
        end

        context "with an existing vaccination record on the same date" do
          let(:performed_at) { Time.zone.local(2026, 1, 5, 9, 30, 50) }

          before { other_vaccination_record }

          it { should_not be_nil }
          it { should_not eq other_vaccination_record }
          its(:pending_changes) { should be_empty }
        end
      end

      context "of type flu" do
        shared_examples "accepts a VACCINE_GIVEN code" do |vaccine_given, snomed_product_code, anatomical_site|
          context "with code: #{vaccine_given}" do
            let(:data) do
              valid_national_reporting_flu_data.merge(
                "VACCINE_GIVEN" => vaccine_given,
                "ANATOMICAL_SITE" => anatomical_site || "right deltoid"
              )
            end

            it { should be_valid }

            its(:vaccine) { should have_attributes(snomed_product_code:) }
          end
        end

        let(:data) { valid_national_reporting_flu_data }

        let(:programme) { Programme.flu }

        it { should be_administered }

        its(:programme) { should eq programme }

        its(:source) { should eq("national_reporting") }

        its(:local_patient_id) { should eq "CIN-OXFORD-pat123456" }

        its(:local_patient_id_uri) do
          should eq "https://cinnamon.nhs.uk/0de/system1"
        end

        its(:location) { should eq location }

        its(:batch_number) { should eq "123" }
        its(:batch_expiry) { should eq Date.new(2026, 1, 6) }

        context "with an unknown school and no name" do
          let(:data) do
            valid_national_reporting_flu_data.merge(
              "SCHOOL_URN" => "888888",
              "SCHOOL_NAME" => nil
            )
          end

          it { should be_valid }
        end

        context "when not administered" do
          let(:data) { { "VACCINATED" => "N" } }

          it { should be_nil }
        end

        context "when Mavis columns are present, which the national reporting upload should ignore" do
          let(:data) do
            valid_national_reporting_flu_data.merge(
              {
                "PROGRAMME" => "HPV",
                "PERFORMING_PROFESSIONAL_EMAIL" => create(:user).email,
                "NOTES" => "Here are some notes",
                "CARE_SETTING" => 2,
                "CLINIC_NAME" => "The Hog's Head",
                "SESSION_ID" => session.id,
                "UUID" => "ABCD1234-26cc-44e4-b886-c3cc90ba01b6",
                "REASON_NOT_VACCINATED" => "Unwell",
                "Vaccination type" => "HPV 1",
                "EVENT_LOCATION_TYPE" => "school",
                "SUPPLIER_EMAIL" => "abc@example.com"
              }
            )
          end

          let(:session) { create(:session, team:, programmes:) }

          it "creates a valid vaccination record" do
            expect(vaccination_record).to be_valid
          end

          its(:programme) { should be Programme.flu }

          its(:performed_by_user) { should be_nil }
          its(:performed_by_given_name) { should eq vaccinator.given_name }
          its(:performed_by_family_name) { should eq vaccinator.family_name }

          its(:notes) { should be_nil }

          its(:location) { should eq location }
          its(:location_name) { should be_nil }

          its(:session) { should be_nil }

          its(:uuid) { should_not eq "ABCD1234-26cc-44e4-b886-c3cc90ba01b6" }

          its(:supplied_by) { should be_nil }
        end

        include_examples "accepts a VACCINE_GIVEN code",
                         "AstraZeneca Fluenz LAIV",
                         "43208811000001106",
                         "nasal"
        include_examples "accepts a VACCINE_GIVEN code",
                         "Viatris Quadrivalent Influvac sub - unit Tetra - QIVe",
                         "45354911000001100"
        include_examples "accepts a VACCINE_GIVEN code",
                         "Seqirus Cell-Based Trivalent IIVc",
                         "43207411000001105"
        include_examples "accepts a VACCINE_GIVEN code",
                         "seqirus cell-based trivalent iivc",
                         "43207411000001105"

        include_examples "with pseudo-postcodes"

        include_examples "date deduplication with existing vaccination records",
                         Programme.flu

        context "when a similar vaccination record exists" do
          let!(:other_vaccination_record) do
            vaccine = Vaccine.find_by(nivs_name: "AstraZeneca Fluenz LAIV")

            create(
              :vaccination_record,
              :sourced_from_national_reporting,
              patient:,
              programme:,
              performed_at: Date.new(2026, 1, 5),
              location:,
              local_patient_id: "CIN-OXFORD-pat123456",
              local_patient_id_uri: "https://cinnamon.nhs.uk/0de/system1",
              performed_by_user: nil,
              performed_by_given_name: vaccinator.given_name,
              performed_by_family_name: vaccinator.family_name,
              vaccine:,
              delivery_site: "nose",
              delivery_method: "nasal_spray",
              batch_number: "456", # different
              batch_expiry: Date.new(2026, 1, 6) # identical
            )
          end

          it { should_not be_nil }
          it { should_not eq other_vaccination_record }
          its(:pending_changes) { should be_empty }
        end

        context "when an identical vaccination record exists" do
          let!(:other_vaccination_record) do
            vaccine = Vaccine.find_by(nivs_name: "AstraZeneca Fluenz LAIV")
            create(
              :vaccination_record,
              :sourced_from_national_reporting,
              patient:,
              programme:,
              performed_at: Date.new(2026, 1, 5),
              location:,
              local_patient_id: "CIN-OXFORD-pat123456",
              local_patient_id_uri: "https://cinnamon.nhs.uk/0de/system1",
              performed_by_user: nil,
              performed_by_given_name: vaccinator.given_name,
              performed_by_family_name: vaccinator.family_name,
              vaccine:,
              delivery_site: "nose",
              delivery_method: "nasal_spray",
              batch_number: "123", # identical
              batch_expiry: Date.new(2026, 1, 6) # identical
            )
          end

          it { should_not be_nil }
          it { should eq other_vaccination_record }
          its(:pending_changes) { should be_empty }
        end
      end

      context "of type hpv" do
        shared_examples "accepts a VACCINE_GIVEN code" do |vaccine_given, snomed_product_code|
          context "with code: #{vaccine_given}" do
            let(:data) do
              valid_national_reporting_hpv_data.merge(
                "VACCINE_GIVEN" => vaccine_given
              )
            end

            it { should be_valid }

            its(:vaccine) { should have_attributes(snomed_product_code:) }
          end
        end

        let(:data) { valid_national_reporting_hpv_data }

        let(:programme) { Programme.hpv }

        it { should be_administered }

        its(:programme) { should eq programme }

        its(:source) { should eq("national_reporting") }

        its(:local_patient_id) { should eq "CIN-OXFORD-pat123456" }

        its(:local_patient_id_uri) do
          should eq "https://cinnamon.nhs.uk/0de/system1"
        end

        its(:location) { should eq location }

        its(:batch_number) { should eq "123" }
        its(:batch_expiry) { should eq Date.new(2026, 1, 6) }

        include_examples "accepts a VACCINE_GIVEN code",
                         "Gardasil",
                         "10880211000001104"
        include_examples "accepts a VACCINE_GIVEN code",
                         "Gardasil9",
                         "33493111000001108"
        include_examples "accepts a VACCINE_GIVEN code",
                         "Cervarix",
                         "12238911000001100"

        context "with an unknown school and no name" do
          let(:data) do
            valid_national_reporting_hpv_data.merge(
              "SCHOOL_URN" => "888888",
              "SCHOOL_NAME" => nil
            )
          end

          it { should be_valid }
        end

        context "when not administered" do
          let(:data) { { "VACCINATED" => "N" } }

          it { should be_nil }
        end

        context "when Mavis columns are present, which the national reporting upload should ignore" do
          let(:data) do
            valid_national_reporting_hpv_data.merge(
              {
                "PROGRAMME" => "Flu",
                "PERFORMING_PROFESSIONAL_EMAIL" => create(:user).email,
                "NOTES" => "Here are some notes",
                "CARE_SETTING" => 2,
                "CLINIC_NAME" => "The Hog's Head",
                "SESSION_ID" => session.id,
                "UUID" => "ABCD1234-26cc-44e4-b886-c3cc90ba01b6",
                "REASON_NOT_VACCINATED" => "Unwell",
                "Vaccination type" => "flu 1",
                "EVENT_LOCATION_TYPE" => "school",
                "SUPPLIER_EMAIL" => "abc@example.com"
              }
            )
          end

          let(:session) { create(:session, team:, programmes:) }

          it "creates a valid vaccination record" do
            expect(vaccination_record).to be_valid
          end

          its(:programme) { should be Programme.hpv }

          its(:performed_by_user) { should be_nil }

          its(:notes) { should be_nil }

          its(:session) { should be_nil }

          its(:uuid) { should_not eq "ABCD1234-26cc-44e4-b886-c3cc90ba01b6" }
        end

        include_examples "with pseudo-postcodes"

        include_examples "date deduplication with existing vaccination records",
                         Programme.hpv
      end
    end
  end

  describe "#batch_expiry" do
    subject { immunisation_import_row.batch_expiry&.to_date }

    context "without a value" do
      let(:data) { {} }

      it { should be_nil }
    end

    context "with an invalid value" do
      let(:data) { { "BATCH_EXPIRY_DATE" => "abc" } }

      it { should be_nil }
    end

    context "with a valid value" do
      let(:data) { { "BATCH_EXPIRY_DATE" => "20100101" } }

      it { should eq(Date.new(2010, 1, 1)) }
    end

    context "with an Excel-exported-to-CSV date format" do
      let(:data) { { "BATCH_EXPIRY_DATE" => "01/09/2027" } }

      it { should eq(Date.new(2027, 9, 1)) }
    end
  end

  describe "#batch_name" do
    subject { immunisation_import_row.batch_name&.to_s }

    context "with a BATCH_NUMBER field" do
      let(:data) { { "BATCH_NUMBER" => "abc" } }

      it { should eq("abc") }
    end

    context "with a Vaccination Batch Number field" do
      let(:data) { { "Vaccination Batch Number" => "abc" } }

      it { should eq("abc") }
    end
  end

  describe "#clinic_name" do
    subject { immunisation_import_row.clinic_name&.to_s }

    context "with a CLINIC_NAME field" do
      let(:data) { { "CLINIC_NAME" => "Hospital" } }

      it { should eq("Hospital") }
    end

    context "with an Event Done At field" do
      let(:data) { { "Event Done At" => "Hospital" } }

      it { should eq("Hospital") }
    end
  end

  describe "#date_of_vaccination" do
    subject { immunisation_import_row.date_of_vaccination&.to_s }

    context "with a DATE_OF_VACCINATION field" do
      let(:data) { { "DATE_OF_VACCINATION" => "01/01/2020" } }

      it { should eq("01/01/2020") }
    end

    context "with an Event Date field" do
      let(:data) { { "Event Date" => "01/01/2020" } }

      it { should eq("01/01/2020") }
    end
  end

  describe "#patient_date_of_birth" do
    subject { immunisation_import_row.patient_date_of_birth&.to_s }

    context "with a PERSON_DOB field" do
      let(:data) { { "PERSON_DOB" => "01/01/2020" } }

      it { should eq("01/01/2020") }
    end

    context "with a Date of Birth field" do
      let(:data) { { "Date of Birth" => "01/01/2020" } }

      it { should eq("01/01/2020") }
    end
  end

  describe "#patient_first_name" do
    subject { immunisation_import_row.patient_first_name&.to_s }

    context "with a PERSON_FORENAME field" do
      let(:data) { { "PERSON_FORENAME" => "Sally" } }

      it { should eq("Sally") }
    end

    context "with a First name field" do
      let(:data) { { "First name" => "Sally" } }

      it { should eq("Sally") }
    end
  end

  describe "#patient_gender_code" do
    subject { immunisation_import_row.patient_gender_code&.to_s }

    context "with a PERSON_GENDER_CODE field" do
      let(:data) { { "PERSON_GENDER_CODE" => "male" } }

      it { should eq("male") }
    end

    context "with a PERSON_GENDER field" do
      let(:data) { { "PERSON_GENDER" => "female" } }

      it { should eq("female") }
    end

    context "with a Sex field" do
      let(:data) { { "Sex" => "unknown" } }

      it { should eq("unknown") }
    end
  end

  describe "#patient_last_name" do
    subject { immunisation_import_row.patient_last_name&.to_s }

    context "with a PERSON_SURNAME field" do
      let(:data) { { "PERSON_SURNAME" => "Phillips" } }

      it { should eq("Phillips") }
    end

    context "with a Surname field" do
      let(:data) { { "Surname" => "Phillips" } }

      it { should eq("Phillips") }
    end
  end

  describe "#performed_by_given_name" do
    subject { immunisation_import_row.performed_by_given_name&.to_s }

    let(:data) { { "PERFORMING_PROFESSIONAL_FORENAME" => "John" } }

    it { should eq("John") }
  end

  describe "#performed_by_family_name" do
    subject { immunisation_import_row.performed_by_family_name&.to_s }

    let(:data) { { "PERFORMING_PROFESSIONAL_SURNAME" => "Smith" } }

    it { should eq("Smith") }
  end

  describe "#school_name" do
    subject { immunisation_import_row.school_name&.to_s }

    context "with a SCHOOL_NAME field" do
      let(:data) { { "SCHOOL_NAME" => "Waterloo Road" } }

      it { should eq("Waterloo Road") }
    end

    context "with a School field" do
      let(:data) { { "School" => "Waterloo Road" } }

      it { should eq("Waterloo Road") }
    end
  end

  describe "#school_urn" do
    subject { immunisation_import_row.school_urn&.to_s }

    context "with a SCHOOL_URN field" do
      let(:data) { { "SCHOOL_URN" => "123456" } }

      it { should eq("123456") }
    end

    context "with a School Code field" do
      let(:data) { { "School Code" => "123456" } }

      it { should eq("123456") }
    end
  end
end
