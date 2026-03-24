# frozen_string_literal: true

describe Reports::OfflineSessionExporter do
  def worksheet_to_hashes(worksheet)
    headers = worksheet[0].cells.map(&:value)
    rows =
      (1..worksheet.count - 1).map do |row_num|
        row = worksheet[row_num]
        next if row.nil?
        headers.zip(row.cells.map { |c| c&.value }).to_h
      end
    rows.compact
  end

  def validation_formula(worksheet:, column_name:, row: 1)
    column = worksheet[0].cells.find_index { it.value == column_name.upcase }

    # stree-ignore
    worksheet
      .data_validations
      .find { |validation|
        validation.sqref.any? do
          it.col_range.include?(column) && it.row_range.include?(row)
        end
      }
      .formula1
      .expression
  end

  subject(:call) { described_class.call(session) }

  shared_examples "generates a report" do
    let(:organisation) { create(:organisation) }
    let(:team) { create(:team, organisation:, programmes: [programme]) }
    let(:user) { create(:user, email: "nurse@example.com", team:) }
    let(:subteam) { create(:subteam, team:) }
    let(:session) do
      create(:session, location:, team:, programmes: [programme])
    end

    let(:academic_year) { session.academic_year }
    let(:patient) { create(:patient, year_group:) }

    before { PatientStatusUpdater.call(patient:) }

    context "a school session" do
      subject(:workbook) { RubyXL::Parser.parse_buffer(call) }

      let(:location) { create(:school, subteam:) }

      it { should_not be_blank }

      describe "headers" do
        subject(:headers) do
          sheet = workbook.worksheets[0]
          sheet[0].cells.map(&:value)
        end

        it do
          expect(headers).to eq(
            %w[
              PERSON_FORENAME
              PERSON_SURNAME
              ORGANISATION_CODE
              SCHOOL_NAME
              CLINIC_NAME
              CARE_SETTING
              PERSON_DOB
              YEAR_GROUP
              REGISTRATION
              PERSON_GENDER_CODE
              PERSON_ADDRESS_LINE_1
              PERSON_POSTCODE
              NHS_NUMBER
              CONSENT_STATUS
              CONSENT_DETAILS
              HEALTH_QUESTION_ANSWERS
              TRIAGE_STATUS
              TRIAGED_BY
              TRIAGE_DATE
              TRIAGE_NOTES
              GILLICK_STATUS
              GILLICK_ASSESSMENT_DATE
              GILLICK_ASSESSED_BY
              GILLICK_ASSESSMENT_NOTES
              VACCINATED
              DATE_OF_VACCINATION
              TIME_OF_VACCINATION
              PROGRAMME
              VACCINE_GIVEN
              PERFORMING_PROFESSIONAL_EMAIL
              SUPPLIER_EMAIL
              BATCH_NUMBER
              BATCH_EXPIRY_DATE
              ANATOMICAL_SITE
              DOSE_SEQUENCE
              REASON_NOT_VACCINATED
              NOTES
              SESSION_ID
              UUID
            ]
          )
        end

        context "with PSD enabled" do
          before { session.update!(psd_enabled: true) }

          it { should include("PSD_STATUS") }
        end
      end

      describe "rows" do
        subject(:rows) { worksheet_to_hashes(workbook.worksheets[0]) }

        let(:performed_at) { Time.zone.local(2024, 1, 1, 12, 5, 20) }
        let(:batch) { build(:batch, :not_expired) }
        let(:batch_number) { batch.number }
        let(:batch_expiry) { batch.expiry }
        let(:patient_location) { create(:patient_location, patient:, session:) }

        it { should be_empty }

        context "with a patient without an outcome" do
          let!(:patient) { create(:patient, session:, year_group:) }

          it "adds a row to fill in" do
            expect(rows.count).to eq(1)
            expect(rows.first.except("PERSON_DOB")).to eq(
              {
                "ANATOMICAL_SITE" => "",
                "BATCH_EXPIRY_DATE" => nil,
                "BATCH_NUMBER" => "",
                "CARE_SETTING" => 1,
                "CLINIC_NAME" => "",
                "CONSENT_DETAILS" => "",
                "CONSENT_STATUS" => "",
                "DATE_OF_VACCINATION" => nil,
                "DOSE_SEQUENCE" => expected_dose_sequence,
                "GILLICK_ASSESSED_BY" => nil,
                "GILLICK_ASSESSMENT_DATE" => nil,
                "GILLICK_ASSESSMENT_NOTES" => nil,
                "GILLICK_STATUS" => "",
                "HEALTH_QUESTION_ANSWERS" => "",
                "NHS_NUMBER" => patient.nhs_number,
                "NOTES" => "",
                "ORGANISATION_CODE" => organisation.ods_code,
                "PERFORMING_PROFESSIONAL_EMAIL" => "",
                "PERSON_ADDRESS_LINE_1" => patient.address_line_1,
                "PERSON_FORENAME" => patient.given_name,
                "PERSON_GENDER_CODE" => "Not known",
                "PERSON_POSTCODE" => patient.address_postcode,
                "PERSON_SURNAME" => patient.family_name,
                "PROGRAMME" => expected_programme,
                "REASON_NOT_VACCINATED" => "",
                "SCHOOL_NAME" => location.name,
                "SESSION_ID" => session.id,
                "SUPPLIER_EMAIL" => "",
                "TIME_OF_VACCINATION" => "",
                "TRIAGED_BY" => nil,
                "TRIAGE_DATE" => nil,
                "TRIAGE_NOTES" => nil,
                "TRIAGE_STATUS" => nil,
                "VACCINATED" => "",
                "VACCINE_GIVEN" => "",
                "UUID" => "",
                "YEAR_GROUP" => patient.year_group(academic_year:),
                "REGISTRATION" => patient.registration
              }
            )
            expect(rows.first["PERSON_DOB"].to_date).to eq(
              patient.date_of_birth
            )
          end

          context "with PSD enabled" do
            before { session.update!(psd_enabled: true) }

            it "adds a PSD status column" do
              expect(rows.count).to eq(1)
              expect(rows.first["PSD_STATUS"]).to be_blank
            end

            context "and the patient has a PSD" do
              before do
                create(:patient_specific_direction, programme:, patient:)
              end

              it "adds a PSD status column" do
                expect(rows.count).to eq(1)
                expect(rows.first["PSD_STATUS"]).to eq("PSD added")
              end
            end

            context "and the patient has an invalidated PSD" do
              before do
                create(
                  :patient_specific_direction,
                  :invalidated,
                  programme:,
                  patient:
                )
              end

              it "adds a blank PSD status column" do
                expect(rows.count).to eq(1)
                expect(rows.first["PSD_STATUS"]).to eq("")
              end
            end
          end
        end

        context "with a restricted patient" do
          before { create(:patient, :restricted, session:) }

          it "doesn't include the address or postcode" do
            expect(rows.count).to eq(1)
            expect(rows.first["PERSON_ADDRESS_LINE_1"]).to be_blank
            expect(rows.first["PERSON_POSTCODE"]).to be_blank
          end
        end

        context "with a triage assessment" do
          let!(:patient) do
            create(
              :patient,
              :consent_given_triage_safe_to_vaccinate,
              session:,
              year_group:
            )
          end

          it "adds a row with the triage details" do
            expect(rows.count).to eq(1)
            expected_status =
              (
                if programme.flu?
                  "Safe to vaccinate with injection"
                else
                  "Safe to vaccinate"
                end
              )
            expect(rows.first["TRIAGE_STATUS"]).to eq(expected_status)
            expect(rows.first["TRIAGED_BY"]).to be_present

            triage =
              patient.triages.for_programme(programme).find_by(academic_year:)
            expect(Time.zone.parse(rows.first["TRIAGE_DATE"]).to_i).to eq(
              triage.created_at.to_i
            )
            expect(rows.first["TRIAGE_NOTES"]).to eq(triage.notes)
          end
        end

        context "with a vaccinated patient" do
          before { create(:patient_location, patient:, session:) }

          let!(:vaccination_record) do
            create(
              :vaccination_record,
              performed_at:,
              batch_number:,
              batch_expiry:,
              patient:,
              session:,
              programme: programme.variant_for(patient:),
              performed_by: user,
              notes: "Some notes."
            )
          end

          it "adds a row with the vaccination details" do
            expect(rows.count).to eq(1)
            expect(
              rows.first.except(
                "BATCH_EXPIRY_DATE",
                "PERSON_DOB",
                "DATE_OF_VACCINATION"
              )
            ).to eq(
              {
                "ANATOMICAL_SITE" => "left upper arm",
                "BATCH_NUMBER" => batch_number,
                "CARE_SETTING" => 1,
                "CLINIC_NAME" => "",
                "CONSENT_DETAILS" => "",
                "CONSENT_STATUS" => "",
                "DOSE_SEQUENCE" => vaccination_record.dose_sequence || "",
                "GILLICK_ASSESSED_BY" => nil,
                "GILLICK_ASSESSMENT_DATE" => nil,
                "GILLICK_ASSESSMENT_NOTES" => nil,
                "GILLICK_STATUS" => "",
                "HEALTH_QUESTION_ANSWERS" => "",
                "NHS_NUMBER" => patient.nhs_number,
                "NOTES" => "Some notes.",
                "ORGANISATION_CODE" => organisation.ods_code,
                "PERFORMING_PROFESSIONAL_EMAIL" => "nurse@example.com",
                "PERSON_ADDRESS_LINE_1" => patient.address_line_1,
                "PERSON_FORENAME" => patient.given_name,
                "PERSON_GENDER_CODE" => "Not known",
                "PERSON_POSTCODE" => patient.address_postcode,
                "PERSON_SURNAME" => patient.family_name,
                "PROGRAMME" => expected_programme,
                "REASON_NOT_VACCINATED" => "",
                "SCHOOL_NAME" => location.name,
                "SESSION_ID" => session.id,
                "SUPPLIER_EMAIL" => nil,
                "TIME_OF_VACCINATION" => "12:05:20",
                "TRIAGED_BY" => nil,
                "TRIAGE_DATE" => nil,
                "TRIAGE_NOTES" => nil,
                "TRIAGE_STATUS" => nil,
                "VACCINATED" => "Y",
                "VACCINE_GIVEN" => vaccination_record.vaccine.upload_name,
                "UUID" => vaccination_record.uuid,
                "YEAR_GROUP" => patient.year_group(academic_year:),
                "REGISTRATION" => patient.registration
              }
            )
            expect(rows.first["BATCH_EXPIRY_DATE"].to_date).to eq(batch_expiry)
            expect(rows.first["PERSON_DOB"].to_date).to eq(
              patient.date_of_birth
            )
            expect(rows.first["DATE_OF_VACCINATION"].to_date).to eq(
              performed_at.to_date
            )
          end

          context "with a supplier" do
            let(:supplied_by) { create(:nurse) }

            before { vaccination_record.update!(supplied_by:) }

            it "includes the supplier" do
              expect(rows.first["SUPPLIER_EMAIL"]).to eq(supplied_by.email)
            end
          end

          context "with consent" do
            before do
              create(
                :consent,
                :from_dad,
                patient:,
                programme:,
                health_questions_list: ["First question?", "Second question?"]
              )
              patient.programme_status(programme, academic_year:).update!(
                consent_status: "given",
                consent_vaccine_methods: %w[nasal injection]
              )
            end

            it "includes the status" do
              expect(rows.first["CONSENT_STATUS"]).to eq(
                expected_consent_status
              )
            end

            it "separates the answers by new lines" do
              expect(rows.first["HEALTH_QUESTION_ANSWERS"]).to eq(
                "First question? No from Dad\nSecond question? No from Dad"
              )
            end
          end
        end

        context "with a vaccinated patient outside the session" do
          before { create(:patient_location, patient:, session:) }

          let!(:vaccination_record) do
            create(
              :vaccination_record,
              performed_at:,
              batch_number:,
              batch_expiry:,
              patient:,
              programme: programme.variant_for(patient:),
              performed_by: user,
              notes: "Some notes.",
              location_name: "Waterloo Road"
            )
          end

          it "adds a row with the vaccination details" do
            expect(rows.count).to eq(1)
            expect(
              rows.first.except(
                "BATCH_EXPIRY_DATE",
                "PERSON_DOB",
                "DATE_OF_VACCINATION"
              )
            ).to eq(
              {
                "ANATOMICAL_SITE" => "left upper arm",
                "BATCH_NUMBER" => batch_number,
                "CARE_SETTING" => nil,
                "CLINIC_NAME" => "",
                "CONSENT_DETAILS" => "",
                "CONSENT_STATUS" => "",
                "DOSE_SEQUENCE" => vaccination_record.dose_sequence || "",
                "GILLICK_ASSESSED_BY" => nil,
                "GILLICK_ASSESSMENT_DATE" => nil,
                "GILLICK_ASSESSMENT_NOTES" => nil,
                "GILLICK_STATUS" => "",
                "HEALTH_QUESTION_ANSWERS" => "",
                "NHS_NUMBER" => patient.nhs_number,
                "NOTES" => "Some notes.",
                "ORGANISATION_CODE" => organisation.ods_code,
                "PERFORMING_PROFESSIONAL_EMAIL" => "nurse@example.com",
                "PERSON_ADDRESS_LINE_1" => patient.address_line_1,
                "PERSON_FORENAME" => patient.given_name,
                "PERSON_GENDER_CODE" => "Not known",
                "PERSON_POSTCODE" => patient.address_postcode,
                "PERSON_SURNAME" => patient.family_name,
                "PROGRAMME" => expected_programme,
                "REASON_NOT_VACCINATED" => "",
                "SCHOOL_NAME" => "Waterloo Road",
                "SESSION_ID" => nil,
                "SUPPLIER_EMAIL" => nil,
                "TIME_OF_VACCINATION" => "12:05:20",
                "TRIAGED_BY" => nil,
                "TRIAGE_DATE" => nil,
                "TRIAGE_NOTES" => nil,
                "TRIAGE_STATUS" => nil,
                "VACCINATED" => "Y",
                "VACCINE_GIVEN" => nil,
                "UUID" => vaccination_record.uuid,
                "YEAR_GROUP" => patient.year_group(academic_year:),
                "REGISTRATION" => patient.registration
              }
            )
            expect(rows.first["BATCH_EXPIRY_DATE"].to_date).to eq(batch_expiry)
            expect(rows.first["PERSON_DOB"].to_date).to eq(
              patient.date_of_birth
            )
            expect(rows.first["DATE_OF_VACCINATION"].to_date).to eq(
              performed_at.to_date
            )
          end
        end

        context "with a vaccinated patient outside the school session, but in a clinic" do
          let(:clinic_session) do
            create(
              :session,
              team:,
              location: team.generic_clinic,
              programmes: [programme]
            )
          end

          let!(:vaccination_record) do
            create(
              :vaccination_record,
              performed_at:,
              batch_number:,
              batch_expiry:,
              patient:,
              session: clinic_session,
              programme: programme.variant_for(patient:),
              performed_by: user,
              notes: "Some notes.",
              location_name: "Waterloo Hospital"
            )
          end

          before do
            create(:patient_location, patient:, session:)
            create(:patient_location, patient:, session: clinic_session)
          end

          it "adds a row with the vaccination details" do
            expect(rows.count).to eq(1)
            expect(
              rows.first.except(
                "BATCH_EXPIRY_DATE",
                "PERSON_DOB",
                "DATE_OF_VACCINATION"
              )
            ).to eq(
              {
                "ANATOMICAL_SITE" => "left upper arm",
                "BATCH_NUMBER" => batch_number,
                "CARE_SETTING" => 2,
                "CLINIC_NAME" => "Waterloo Hospital",
                "CONSENT_DETAILS" => "",
                "CONSENT_STATUS" => "",
                "DOSE_SEQUENCE" => vaccination_record.dose_sequence || "",
                "GILLICK_ASSESSED_BY" => nil,
                "GILLICK_ASSESSMENT_DATE" => nil,
                "GILLICK_ASSESSMENT_NOTES" => nil,
                "GILLICK_STATUS" => "",
                "HEALTH_QUESTION_ANSWERS" => "",
                "NHS_NUMBER" => patient.nhs_number,
                "NOTES" => "Some notes.",
                "ORGANISATION_CODE" => organisation.ods_code,
                "PERFORMING_PROFESSIONAL_EMAIL" => "nurse@example.com",
                "PERSON_ADDRESS_LINE_1" => patient.address_line_1,
                "PERSON_FORENAME" => patient.given_name,
                "PERSON_GENDER_CODE" => "Not known",
                "PERSON_POSTCODE" => patient.address_postcode,
                "PERSON_SURNAME" => patient.family_name,
                "PROGRAMME" => expected_programme,
                "REASON_NOT_VACCINATED" => "",
                "SCHOOL_NAME" => "",
                "SESSION_ID" => clinic_session.id,
                "SUPPLIER_EMAIL" => nil,
                "TIME_OF_VACCINATION" => "12:05:20",
                "TRIAGED_BY" => nil,
                "TRIAGE_DATE" => nil,
                "TRIAGE_NOTES" => nil,
                "TRIAGE_STATUS" => nil,
                "VACCINATED" => "Y",
                "VACCINE_GIVEN" => vaccination_record.vaccine.upload_name,
                "UUID" => vaccination_record.uuid,
                "YEAR_GROUP" => patient.year_group(academic_year:),
                "REGISTRATION" => patient.registration
              }
            )
            expect(rows.first["BATCH_EXPIRY_DATE"].to_date).to eq(batch_expiry)
            expect(rows.first["PERSON_DOB"].to_date).to eq(
              patient.date_of_birth
            )
            expect(rows.first["DATE_OF_VACCINATION"].to_date).to eq(
              performed_at.to_date
            )
          end
        end

        context "with a vaccinated patient for a different programme" do
          before do
            create(:patient_location, patient:, session:)

            other_programme_type = (Programme::TYPES - [programme.type]).sample

            create(
              :vaccination_record,
              performed_at:,
              batch_number:,
              batch_expiry:,
              patient:,
              programme: Programme.find(other_programme_type),
              performed_by: user,
              notes: "Some notes.",
              location_name: "Waterloo Road"
            )

            PatientStatusUpdater.call(patient:)
          end

          it "adds a row to fill in" do
            expect(rows.count).to eq(1)
            expect(rows.first.except("PERSON_DOB")).to eq(
              {
                "ANATOMICAL_SITE" => "",
                "BATCH_EXPIRY_DATE" => nil,
                "BATCH_NUMBER" => "",
                "CARE_SETTING" => 1,
                "CLINIC_NAME" => "",
                "CONSENT_DETAILS" => "",
                "CONSENT_STATUS" => "",
                "DATE_OF_VACCINATION" => nil,
                "DOSE_SEQUENCE" => expected_dose_sequence,
                "GILLICK_ASSESSED_BY" => nil,
                "GILLICK_ASSESSMENT_DATE" => nil,
                "GILLICK_ASSESSMENT_NOTES" => nil,
                "GILLICK_STATUS" => "",
                "HEALTH_QUESTION_ANSWERS" => "",
                "NHS_NUMBER" => patient.nhs_number,
                "NOTES" => "",
                "ORGANISATION_CODE" => organisation.ods_code,
                "PERFORMING_PROFESSIONAL_EMAIL" => "",
                "PERSON_ADDRESS_LINE_1" => patient.address_line_1,
                "PERSON_FORENAME" => patient.given_name,
                "PERSON_GENDER_CODE" => "Not known",
                "PERSON_POSTCODE" => patient.address_postcode,
                "PERSON_SURNAME" => patient.family_name,
                "PROGRAMME" => expected_programme,
                "REASON_NOT_VACCINATED" => "",
                "SCHOOL_NAME" => location.name,
                "SESSION_ID" => session.id,
                "SUPPLIER_EMAIL" => "",
                "TIME_OF_VACCINATION" => "",
                "TRIAGED_BY" => nil,
                "TRIAGE_DATE" => nil,
                "TRIAGE_NOTES" => nil,
                "TRIAGE_STATUS" => nil,
                "VACCINATED" => "",
                "VACCINE_GIVEN" => "",
                "UUID" => "",
                "YEAR_GROUP" => patient.year_group(academic_year:),
                "REGISTRATION" => patient.registration
              }
            )
            expect(rows.first["PERSON_DOB"].to_date).to eq(
              patient.date_of_birth
            )
          end
        end

        context "with a patient who couldn't be vaccinated" do
          before { create(:patient_location, patient:, session:) }

          let!(:vaccination_record) do
            create(
              :vaccination_record,
              :not_administered,
              patient:,
              session:,
              programme: programme.variant_for(patient:),
              performed_at:,
              performed_by: user,
              notes: "Some notes."
            )
          end

          it "adds a row to fill in" do
            expect(rows.count).to eq(1)
            expect(
              rows.first.except("DATE_OF_VACCINATION", "PERSON_DOB")
            ).to eq(
              {
                "ANATOMICAL_SITE" => "",
                "BATCH_EXPIRY_DATE" => nil,
                "BATCH_NUMBER" => nil,
                "CARE_SETTING" => 1,
                "CLINIC_NAME" => "",
                "CONSENT_DETAILS" => "",
                "CONSENT_STATUS" => "",
                "DOSE_SEQUENCE" => "",
                "GILLICK_ASSESSED_BY" => nil,
                "GILLICK_ASSESSMENT_DATE" => nil,
                "GILLICK_ASSESSMENT_NOTES" => nil,
                "GILLICK_STATUS" => "",
                "HEALTH_QUESTION_ANSWERS" => "",
                "NHS_NUMBER" => patient.nhs_number,
                "NOTES" => "Some notes.",
                "ORGANISATION_CODE" => organisation.ods_code,
                "PERFORMING_PROFESSIONAL_EMAIL" => "nurse@example.com",
                "PERSON_ADDRESS_LINE_1" => patient.address_line_1,
                "PERSON_FORENAME" => patient.given_name,
                "PERSON_GENDER_CODE" => "Not known",
                "PERSON_POSTCODE" => patient.address_postcode,
                "PERSON_SURNAME" => patient.family_name,
                "PROGRAMME" => expected_programme,
                "REASON_NOT_VACCINATED" => "unwell",
                "SCHOOL_NAME" => location.name,
                "SESSION_ID" => session.id,
                "SUPPLIER_EMAIL" => nil,
                "TIME_OF_VACCINATION" => "12:05:20",
                "TRIAGED_BY" => nil,
                "TRIAGE_DATE" => nil,
                "TRIAGE_NOTES" => nil,
                "TRIAGE_STATUS" => nil,
                "VACCINATED" => "N",
                "VACCINE_GIVEN" => nil,
                "UUID" => vaccination_record.uuid,
                "YEAR_GROUP" => patient.year_group(academic_year:),
                "REGISTRATION" => patient.registration
              }
            )
            expect(rows.first["DATE_OF_VACCINATION"].to_date).to eq(
              performed_at.to_date
            )
            expect(rows.first["PERSON_DOB"].to_date).to eq(
              patient.date_of_birth
            )
          end
        end
      end

      describe "cell validations" do
        subject(:worksheet) { workbook.worksheets[0] }

        before do
          # Without a patient no validation will be setup.
          create(:patient, session:)
        end

        describe "performing professional email" do
          subject(:validation) do
            create(:user, team:, email: "vaccinator@example.com")
            validation_formula(
              worksheet:,
              column_name: "performing_professional_email"
            )
          end

          it { should eq "='Performing Professionals'!$A2:$A2" }
        end

        describe "batch number" do
          subject(:validation) do
            create(
              :batch,
              :not_expired,
              number: "BATCH12345",
              vaccine: programme.vaccines.active.first,
              team:
            )
            validation_formula(worksheet:, column_name: "batch_number")
          end

          it { should eq "='#{programme.type} Batch Numbers'!$A2:$A2" }
        end

        describe "vaccine given" do
          let(:patient) { create(:patient, session:) }

          it "only has the vaccine names for the programme or programme variant" do
            vaccines =
              Vaccine
                .active
                .for_programmes([programme.variant_for(patient:)])
                .pluck(:upload_name)
                .join(", ")

            formula =
              validation_formula(worksheet:, column_name: "vaccine_given")
            expect(formula).to eq("\"#{vaccines}\"")
          end
        end
      end

      describe "performing professionals sheet" do
        subject(:worksheet) do
          workbook.worksheets.find do
            it.sheet_name == "Performing Professionals"
          end
        end

        let!(:vaccinators) { create_list(:user, 2, team:) }

        before do
          create(:patient, session:)
          create(
            :user,
            team: create(:team),
            email: "vaccinator.other@example.com"
          )
        end

        it "lists all the team users' emails" do
          emails = worksheet[1..].map { it.cells.first.value }
          expect(emails).to include(*vaccinators.map(&:email))
        end

        its(:state) { should eq "hidden" }
        its(:sheet_protection) { should be_present }
      end

      describe "batch numbers sheet" do
        subject(:worksheet) do
          workbook.worksheets.find do
            it.sheet_name == "#{programme.type} Batch Numbers"
          end
        end

        let!(:batches) do
          create_list(
            :batch,
            2,
            :not_expired,
            vaccine: programme.vaccines.active.first,
            team:
          )
        end

        before do
          create(:patient, session:)

          other_programme_type = (Programme::TYPES - [programme.type]).sample

          create(
            :batch,
            :not_expired,
            number: "OTHERBATCH",
            vaccine: Programme.find(other_programme_type).vaccines.first
          )
        end

        it "lists all the batch numbers for the programme" do
          batch_numbers = worksheet[1..].map { it.cells.first.value }
          expect(batch_numbers).to include(*batches.map(&:number))
        end

        its(:state) { should eq "hidden" }
        its(:sheet_protection) { should be_present }
      end
    end

    context "a clinic session" do
      subject(:workbook) { RubyXL::Parser.parse_buffer(call) }

      let(:location) { team.locations.generic_clinic.first }

      it { should_not be_blank }

      describe "headers" do
        subject(:headers) do
          sheet = workbook.worksheets[0]
          sheet[0].cells.map(&:value)
        end

        it do
          expect(headers).to eq(
            %w[
              PERSON_FORENAME
              PERSON_SURNAME
              ORGANISATION_CODE
              SCHOOL_NAME
              CLINIC_NAME
              CARE_SETTING
              PERSON_DOB
              YEAR_GROUP
              REGISTRATION
              PERSON_GENDER_CODE
              PERSON_ADDRESS_LINE_1
              PERSON_POSTCODE
              NHS_NUMBER
              CONSENT_STATUS
              CONSENT_DETAILS
              HEALTH_QUESTION_ANSWERS
              TRIAGE_STATUS
              TRIAGED_BY
              TRIAGE_DATE
              TRIAGE_NOTES
              GILLICK_STATUS
              GILLICK_ASSESSMENT_DATE
              GILLICK_ASSESSED_BY
              GILLICK_ASSESSMENT_NOTES
              VACCINATED
              DATE_OF_VACCINATION
              TIME_OF_VACCINATION
              PROGRAMME
              VACCINE_GIVEN
              PERFORMING_PROFESSIONAL_EMAIL
              SUPPLIER_EMAIL
              BATCH_NUMBER
              BATCH_EXPIRY_DATE
              ANATOMICAL_SITE
              DOSE_SEQUENCE
              REASON_NOT_VACCINATED
              NOTES
              SESSION_ID
              UUID
            ]
          )
        end
      end

      describe "rows" do
        subject(:rows) { worksheet_to_hashes(workbook.worksheets[0]) }

        it { should be_empty }

        context "with a patient without an outcome" do
          let!(:patient) { create(:patient, session:, year_group:) }

          it "adds a row to fill in" do
            expect(rows.count).to eq(1)
            expect(rows.first.except("PERSON_DOB")).to eq(
              {
                "ANATOMICAL_SITE" => "",
                "BATCH_EXPIRY_DATE" => nil,
                "BATCH_NUMBER" => "",
                "CARE_SETTING" => 2,
                "CONSENT_DETAILS" => "",
                "CONSENT_STATUS" => "",
                "CLINIC_NAME" => "",
                "DATE_OF_VACCINATION" => nil,
                "DOSE_SEQUENCE" => expected_dose_sequence,
                "GILLICK_ASSESSED_BY" => nil,
                "GILLICK_ASSESSMENT_DATE" => nil,
                "GILLICK_ASSESSMENT_NOTES" => nil,
                "GILLICK_STATUS" => "",
                "HEALTH_QUESTION_ANSWERS" => "",
                "NHS_NUMBER" => patient.nhs_number,
                "NOTES" => "",
                "ORGANISATION_CODE" => organisation.ods_code,
                "PERFORMING_PROFESSIONAL_EMAIL" => "",
                "PERSON_ADDRESS_LINE_1" => patient.address_line_1,
                "PERSON_FORENAME" => patient.given_name,
                "PERSON_GENDER_CODE" => "Not known",
                "PERSON_POSTCODE" => patient.address_postcode,
                "PERSON_SURNAME" => patient.family_name,
                "PROGRAMME" => expected_programme,
                "REASON_NOT_VACCINATED" => "",
                "SCHOOL_NAME" => "",
                "SESSION_ID" => session.id,
                "SUPPLIER_EMAIL" => "",
                "TIME_OF_VACCINATION" => "",
                "TRIAGED_BY" => nil,
                "TRIAGE_DATE" => nil,
                "TRIAGE_NOTES" => nil,
                "TRIAGE_STATUS" => nil,
                "VACCINATED" => "",
                "VACCINE_GIVEN" => "",
                "UUID" => "",
                "YEAR_GROUP" => patient.year_group(academic_year:),
                "REGISTRATION" => patient.registration
              }
            )
            expect(rows.first["PERSON_DOB"].to_date).to eq(
              patient.date_of_birth
            )
          end
        end

        context "with a vaccinated patient" do
          let(:patient) do
            create(
              :patient,
              year_group:,
              school: create(:school, urn: "123456", name: "Waterloo Road")
            )
          end
          let(:batch_number) { build(:batch).number }
          let(:batch_expiry) { build(:batch, :not_expired).expiry }
          let(:performed_at) { Time.zone.local(2024, 1, 1, 12, 5, 20) }
          let!(:vaccination_record) do
            create(
              :vaccination_record,
              performed_at:,
              batch_number:,
              batch_expiry:,
              patient:,
              session:,
              programme: programme.variant_for(patient:),
              location_name: "A Clinic",
              performed_by: user,
              notes: "Some notes."
            )
          end

          before { create(:patient_location, patient:, session:) }

          it "adds a row to fill in" do
            expect(rows.count).to eq(1)
            expect(
              rows.first.except(
                "BATCH_EXPIRY_DATE",
                "PERSON_DOB",
                "DATE_OF_VACCINATION"
              )
            ).to eq(
              {
                "ANATOMICAL_SITE" => "left upper arm",
                "BATCH_NUMBER" => batch_number,
                "CARE_SETTING" => 2,
                "CONSENT_DETAILS" => "",
                "CONSENT_STATUS" => "",
                "CLINIC_NAME" => "A Clinic",
                "DOSE_SEQUENCE" => vaccination_record.dose_sequence || "",
                "GILLICK_ASSESSED_BY" => nil,
                "GILLICK_ASSESSMENT_DATE" => nil,
                "GILLICK_ASSESSMENT_NOTES" => nil,
                "GILLICK_STATUS" => "",
                "HEALTH_QUESTION_ANSWERS" => "",
                "NHS_NUMBER" => patient.nhs_number,
                "NOTES" => "Some notes.",
                "ORGANISATION_CODE" => organisation.ods_code,
                "PERFORMING_PROFESSIONAL_EMAIL" => "nurse@example.com",
                "PERSON_ADDRESS_LINE_1" => patient.address_line_1,
                "PERSON_FORENAME" => patient.given_name,
                "PERSON_GENDER_CODE" => "Not known",
                "PERSON_POSTCODE" => patient.address_postcode,
                "PERSON_SURNAME" => patient.family_name,
                "PROGRAMME" => expected_programme,
                "REASON_NOT_VACCINATED" => "",
                "SCHOOL_NAME" => "Waterloo Road",
                "SESSION_ID" => session.id,
                "SUPPLIER_EMAIL" => nil,
                "TIME_OF_VACCINATION" => "12:05:20",
                "TRIAGED_BY" => nil,
                "TRIAGE_DATE" => nil,
                "TRIAGE_NOTES" => nil,
                "TRIAGE_STATUS" => nil,
                "VACCINATED" => "Y",
                "VACCINE_GIVEN" => vaccination_record.vaccine.upload_name,
                "UUID" => vaccination_record.uuid,
                "YEAR_GROUP" => patient.year_group(academic_year:),
                "REGISTRATION" => patient.registration
              }
            )
            expect(rows.first["BATCH_EXPIRY_DATE"].to_date).to eq(batch_expiry)
            expect(rows.first["PERSON_DOB"].to_date).to eq(
              patient.date_of_birth
            )
            expect(rows.first["DATE_OF_VACCINATION"].to_date).to eq(
              performed_at.to_date
            )
          end
        end
      end

      describe "cell validations" do
        subject(:worksheet) { workbook.worksheets[0] }

        before do
          create(:patient, session:)
          create(:user, team:, email: "vaccinator@example.com")
        end

        describe "performing professional email" do
          subject(:validation) do
            worksheet = workbook.worksheets[0]
            validation_formula(
              worksheet:,
              column_name: "performing_professional_email"
            )
          end

          it { should eq "='Performing Professionals'!$A2:$A2" }
        end

        describe "batch number" do
          subject(:validation) do
            create(
              :batch,
              :not_expired,
              number: "BATCH12345",
              vaccine: programme.vaccines.active.first,
              team:
            )
            validation_formula(worksheet:, column_name: "batch_number")
          end

          it { should eq "='#{programme.type} Batch Numbers'!$A2:$A2" }
        end
      end

      describe "performing professionals sheet" do
        subject(:worksheet) do
          workbook.worksheets.find do
            it.sheet_name == "Performing Professionals"
          end
        end

        let!(:vaccinators) { create_list(:user, 2, team:) }

        before do
          create(:patient, session:)
          create(
            :user,
            team: create(:team),
            email: "vaccinator.other@example.com"
          )
        end

        it "lists all the team users' emails" do
          emails = worksheet[1..].map { it.cells.first.value }
          expect(emails).to match_array(vaccinators.map(&:email))
        end

        its(:state) { should eq "hidden" }
        its(:sheet_protection) { should be_present }
      end

      describe "batch numbers sheet" do
        subject(:worksheet) do
          workbook.worksheets.find do
            it.sheet_name == "#{programme.type} Batch Numbers"
          end
        end

        let!(:batches) do
          create_list(
            :batch,
            2,
            :not_expired,
            vaccine: programme.vaccines.active.first,
            team:
          )
        end

        before do
          create(:patient, session:)

          other_programme_type = (Programme::TYPES - [programme.type]).sample

          create(
            :batch,
            :not_expired,
            number: "OTHERBATCH",
            vaccine: Programme.find(other_programme_type).vaccines.first
          )
        end

        it "lists all the batch numbers for the programme" do
          batch_numbers = worksheet[1..].map { it.cells.first.value }
          expect(batch_numbers).to match_array(batches.map(&:number))
        end

        its(:state) { should eq "hidden" }
        its(:sheet_protection) { should be_present }
      end
    end
  end

  context "Flu programme" do
    let(:programme) { Programme.flu }
    let(:year_group) { 6 }

    let(:expected_programme) { "Flu" }
    let(:expected_dose_sequence) { 1 }
    let(:expected_consent_status) do
      "Consent given for nasal spray and injection"
    end

    include_examples "generates a report"

    context "with a triage assessment for injection only" do
      subject(:rows) { worksheet_to_hashes(workbook.worksheets[0]) }

      let(:session) { create(:session, programmes: [programme]) }
      let(:patient) do
        create(
          :patient,
          :consent_given_nasal_triage_safe_to_vaccinate_nasal,
          session:,
          year_group:
        )
      end
      let(:workbook) { RubyXL::Parser.parse_buffer(call) }

      it "adds a row with the triage details" do
        patient

        expect(rows.count).to eq(1)
        expect(rows.first["TRIAGE_STATUS"]).to eq(
          "Safe to vaccinate with nasal spray"
        )
      end
    end
  end

  context "HPV programme" do
    let(:programme) { Programme.hpv }
    let(:year_group) { 8 }

    let(:expected_programme) { "HPV" }
    let(:expected_dose_sequence) { 1 }
    let(:expected_consent_status) { "Consent given" }

    include_examples "generates a report"
  end

  context "MenACWY programme" do
    let(:programme) { Programme.menacwy }
    let(:year_group) { 9 }

    let(:expected_programme) { "ACWYX4" }
    let(:expected_dose_sequence) { 1 }
    let(:expected_consent_status) { "Consent given" }

    include_examples "generates a report"
  end

  context "MMR programme" do
    let(:programme) { Programme.mmr }
    let(:year_group) { 11 }

    let(:expected_programme) { "MMR" }
    let(:expected_dose_sequence) { 1 }
    let(:expected_consent_status) { "Consent given" }

    include_examples "generates a report"
  end

  context "MMRV programme" do
    let(:programme) { Programme.mmr }
    let(:year_group) { 0 }

    let(:expected_programme) { "MMRV" }
    let(:expected_dose_sequence) { 1 }
    let(:expected_consent_status) { "Consent given" }

    include_examples "generates a report"
  end

  context "Td/IPV programme" do
    let(:programme) { Programme.td_ipv }
    let(:year_group) { 9 }

    let(:expected_programme) { "3-in-1" }
    let(:expected_dose_sequence) { 5 }
    let(:expected_consent_status) { "Consent given" }

    include_examples "generates a report"
  end

  describe "#vaccine_values_for_programmes" do
    let(:programme) { Programme.mmr }
    let(:mmr_programme_variant) do
      Programme::Variant.new(programme, variant_type: "mmr")
    end
    let(:mmrv_programme_variant) do
      Programme::Variant.new(programme, variant_type: "mmrv")
    end
    let(:session) { create(:session, programmes: [programme]) }

    it "returns the correct vaccines for the given programme variants" do
      exporter = described_class.send(:new, session)

      expect(
        exporter.send(:vaccine_values_for_programme, mmr_programme_variant)
      ).to eq(%w[Priorix VaxPro])

      expect(
        exporter.send(:vaccine_values_for_programme, mmrv_programme_variant)
      ).to eq(%w[ProQuad Priorix-Tetra])
    end
  end
end
