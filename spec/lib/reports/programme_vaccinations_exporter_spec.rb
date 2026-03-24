# frozen_string_literal: true

describe Reports::ProgrammeVaccinationsExporter do
  subject(:call) do
    described_class.call(
      team:,
      programme:,
      academic_year:,
      start_date:,
      end_date:
    )
  end

  let(:today) { Time.zone.local(2024, 4, 1) }
  let(:academic_year) { today.to_date.academic_year }

  around { |example| travel_to(today) { example.run } }

  shared_examples "generates a report" do
    let(:programmes) { [programme] }
    let(:organisation) { create(:organisation) }
    let(:team) { create(:team, organisation:, programmes:) }
    let(:user) do
      create(
        :user,
        email: "nurse@example.com",
        given_name: "Nurse",
        family_name: "Test",
        team:
      )
    end
    let(:subteam) { create(:subteam, team:) }
    let(:session) { create(:session, location:, team:, programmes:) }

    let(:start_date) { nil }
    let(:end_date) { nil }

    describe "headers" do
      subject(:headers) { CSV.parse(call).first }

      it do
        expect(headers).to eq(
          %w[
            ORGANISATION_CODE
            SCHOOL_URN
            SCHOOL_NAME
            CARE_SETTING
            CLINIC_NAME
            PERSON_FORENAME
            PERSON_SURNAME
            PERSON_DATE_OF_BIRTH
            PERSON_DATE_OF_DEATH
            YEAR_GROUP
            PERSON_GENDER_CODE
            PERSON_ADDRESS_LINE_1
            PERSON_POSTCODE
            NHS_NUMBER
            NHS_NUMBER_STATUS_CODE
            GP_ORGANISATION_CODE
            GP_NAME
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
            GILLICK_NOTIFY_PARENTS
            VACCINATED
            DATE_OF_VACCINATION
            TIME_OF_VACCINATION
            PROGRAMME_NAME
            VACCINE_GIVEN
            PROTOCOL
            PERFORMING_PROFESSIONAL_EMAIL
            PERFORMING_PROFESSIONAL_FORENAME
            PERFORMING_PROFESSIONAL_SURNAME
            SUPPLIER_EMAIL
            SUPPLIER_FORENAME
            SUPPLIER_SURNAME
            BATCH_NUMBER
            BATCH_EXPIRY_DATE
            ANATOMICAL_SITE
            ROUTE_OF_VACCINATION
            DOSE_SEQUENCE
            DOSE_VOLUME
            REASON_NOT_VACCINATED
            LOCAL_PATIENT_ID
            SNOMED_PROCEDURE_CODE
            REASON_FOR_INCLUSION
            RECORD_CREATED
            RECORD_UPDATED
          ]
        )
      end
    end

    describe "rows" do
      subject(:rows) { CSV.parse(call, headers: true) }

      context "a school session" do
        let(:location) { create(:gias_school, subteam:) }

        it { should be_empty }

        context "with a vaccinated patient" do
          let(:patient) { create(:patient, session:) }
          let(:batch) do
            create(:batch, expiry: Date.new(2025, 12, 1), vaccine:)
          end
          let(:performed_at) { Time.zone.local(2024, 1, 1, 12, 5, 20) }

          let!(:vaccination_record) do
            create(
              :vaccination_record,
              vaccine:,
              batch:,
              patient:,
              session:,
              performed_at:,
              created_at: performed_at,
              updated_at: performed_at,
              programme:,
              performed_by: user
            )
          end

          it "has a row" do
            expect(rows.count).to eq(1)
            expect(rows.first.to_hash).to eq(
              {
                "ANATOMICAL_SITE" => "left upper arm",
                "BATCH_EXPIRY_DATE" => "2025-12-01",
                "BATCH_NUMBER" => batch.number,
                "CARE_SETTING" => "1",
                "CLINIC_NAME" => "",
                "CONSENT_DETAILS" => "",
                "CONSENT_STATUS" => "",
                "DATE_OF_VACCINATION" => "2024-01-01",
                "DOSE_SEQUENCE" => vaccination_record.dose_sequence.to_s,
                "DOSE_VOLUME" => vaccination_record.dose_volume_ml.to_s,
                "GILLICK_ASSESSED_BY" => "",
                "GILLICK_ASSESSMENT_DATE" => "",
                "GILLICK_ASSESSMENT_NOTES" => "",
                "GILLICK_NOTIFY_PARENTS" => "",
                "GILLICK_STATUS" => "",
                "GP_NAME" => "",
                "GP_ORGANISATION_CODE" => "",
                "HEALTH_QUESTION_ANSWERS" => "",
                "LOCAL_PATIENT_ID" => patient.id.to_s,
                "NHS_NUMBER" => patient.nhs_number,
                "NHS_NUMBER_STATUS_CODE" => "02",
                "ORGANISATION_CODE" => organisation.ods_code,
                "PERFORMING_PROFESSIONAL_EMAIL" => "nurse@example.com",
                "PERFORMING_PROFESSIONAL_FORENAME" => "Nurse",
                "PERFORMING_PROFESSIONAL_SURNAME" => "Test",
                "PERSON_ADDRESS_LINE_1" => patient.address_line_1,
                "PERSON_DATE_OF_BIRTH" =>
                  patient.date_of_birth.strftime("%Y-%m-%d"),
                "PERSON_DATE_OF_DEATH" => "",
                "PERSON_FORENAME" => patient.given_name,
                "PERSON_GENDER_CODE" => "Not known",
                "PERSON_POSTCODE" => patient.address_postcode,
                "PERSON_SURNAME" => patient.family_name,
                "PROGRAMME_NAME" => expected_programme_name,
                "PROTOCOL" => "pgd",
                "REASON_NOT_VACCINATED" => "",
                "RECORD_CREATED" => "2024-01-01T12:05:20+00:00",
                "RECORD_UPDATED" => "",
                "REASON_FOR_INCLUSION" => "new",
                "ROUTE_OF_VACCINATION" => "intramuscular",
                "SCHOOL_NAME" => location.name,
                "SCHOOL_URN" => location.urn,
                "SNOMED_PROCEDURE_CODE" =>
                  vaccination_record.snomed_procedure_code,
                "SUPPLIER_EMAIL" => "",
                "SUPPLIER_FORENAME" => "",
                "SUPPLIER_SURNAME" => "",
                "TIME_OF_VACCINATION" => "12:05:20",
                "TRIAGED_BY" => "",
                "TRIAGE_DATE" => "",
                "TRIAGE_NOTES" => "",
                "TRIAGE_STATUS" => "",
                "VACCINATED" => "Y",
                "VACCINE_GIVEN" => vaccination_record.vaccine.upload_name,
                "YEAR_GROUP" => patient.year_group(academic_year:).to_s
              }
            )
          end

          context "with a supplier" do
            let(:supplied_by) { create(:nurse) }

            before do
              vaccination_record.update!(supplied_by:, protocol: "national")
            end

            it "includes the information" do
              expect(rows.first.to_hash).to include(
                "PROTOCOL" => "national",
                "SUPPLIER_EMAIL" => supplied_by.email,
                "SUPPLIER_FORENAME" => supplied_by.given_name,
                "SUPPLIER_SURNAME" => supplied_by.family_name
              )
            end
          end
        end

        context "with a vaccinated patient outside the date range" do
          let(:patient) { create(:patient_location, session:).patient }
          let(:start_date) { Date.current }

          before do
            create(
              :vaccination_record,
              patient:,
              session:,
              created_at: 1.day.ago,
              updated_at: 1.day.ago,
              programme: programmes.first,
              performed_by: user
            )
          end

          it { should be_empty }
        end

        context "with a vaccinated patient sourced manually" do
          let(:patient) { create(:patient_location, session:).patient }
          let(:start_date) { Date.current }

          before do
            create(
              :vaccination_record,
              :sourced_from_manual_report,
              patient:,
              session:,
              programme: programmes.first,
              performed_by: user
            )
          end

          it { should be_empty }
        end

        context "with a vaccination for a different programme" do
          let(:patient) { create(:patient_location, session:).patient }

          let(:other_programme) do
            create(
              :programme,
              type: (Programme::TYPES - programmes.map(&:type)).sample
            )
          end

          let(:vaccination_record) do
            create(
              :vaccination_record,
              programme: other_programme,
              patient:,
              session:
            )
          end

          it { should be_blank }
        end

        context "with a vaccinated patient that was updated in the date range" do
          let(:patient) { create(:patient_location, session:).patient }
          let(:start_date) { 1.day.ago }

          before do
            create(
              :vaccination_record,
              patient:,
              session:,
              created_at: 10.days.ago,
              updated_at: Time.current,
              programme: programmes.first,
              performed_by: user
            )
          end

          it "includes the information" do
            expect(rows.first.to_hash).to include(
              "REASON_FOR_INCLUSION" => "updated"
            )
          end
        end
      end

      context "a clinic session" do
        let(:location) { create(:generic_clinic, subteam:) }

        it { should be_empty }

        context "with a vaccinated patient" do
          let(:patient) { create(:patient, session:) }
          let(:batch) do
            create(:batch, expiry: Date.new(2025, 12, 1), vaccine:)
          end
          let(:performed_at) { Time.zone.local(2024, 1, 1, 12, 5, 20) }

          let!(:vaccination_record) do
            create(
              :vaccination_record,
              performed_at:,
              vaccine:,
              batch:,
              patient:,
              session:,
              programme:,
              location_name: "A Clinic",
              performed_by: user
            )
          end

          it "has a row" do
            expect(rows.count).to eq(1)
            expect(rows.first.to_hash).to eq(
              {
                "ANATOMICAL_SITE" => "left upper arm",
                "BATCH_EXPIRY_DATE" => "2025-12-01",
                "BATCH_NUMBER" => batch.number,
                "CARE_SETTING" => "2",
                "CLINIC_NAME" => "A Clinic",
                "CONSENT_DETAILS" => "",
                "CONSENT_STATUS" => "",
                "DATE_OF_VACCINATION" => "2024-01-01",
                "DOSE_SEQUENCE" => vaccination_record.dose_sequence.to_s,
                "DOSE_VOLUME" => vaccination_record.dose_volume_ml.to_s,
                "GILLICK_ASSESSED_BY" => "",
                "GILLICK_ASSESSMENT_DATE" => "",
                "GILLICK_ASSESSMENT_NOTES" => "",
                "GILLICK_NOTIFY_PARENTS" => "",
                "GILLICK_STATUS" => "",
                "GP_NAME" => "",
                "GP_ORGANISATION_CODE" => "",
                "HEALTH_QUESTION_ANSWERS" => "",
                "LOCAL_PATIENT_ID" => patient.id.to_s,
                "NHS_NUMBER" => patient.nhs_number,
                "NHS_NUMBER_STATUS_CODE" => "02",
                "ORGANISATION_CODE" => organisation.ods_code,
                "PERFORMING_PROFESSIONAL_EMAIL" => "nurse@example.com",
                "PERFORMING_PROFESSIONAL_FORENAME" => "Nurse",
                "PERFORMING_PROFESSIONAL_SURNAME" => "Test",
                "PERSON_ADDRESS_LINE_1" => patient.address_line_1,
                "PERSON_DATE_OF_BIRTH" =>
                  patient.date_of_birth.strftime("%Y-%m-%d"),
                "PERSON_DATE_OF_DEATH" => "",
                "PERSON_FORENAME" => patient.given_name,
                "PERSON_GENDER_CODE" => "Not known",
                "PERSON_POSTCODE" => patient.address_postcode,
                "PERSON_SURNAME" => patient.family_name,
                "PROGRAMME_NAME" => expected_programme_name,
                "PROTOCOL" => "pgd",
                "REASON_NOT_VACCINATED" => "",
                "RECORD_CREATED" => Time.current.iso8601,
                "RECORD_UPDATED" => "",
                "REASON_FOR_INCLUSION" => "new",
                "ROUTE_OF_VACCINATION" => "intramuscular",
                "SCHOOL_NAME" => "",
                "SCHOOL_URN" => "888888",
                "SNOMED_PROCEDURE_CODE" =>
                  vaccination_record.snomed_procedure_code,
                "SUPPLIER_EMAIL" => "",
                "SUPPLIER_FORENAME" => "",
                "SUPPLIER_SURNAME" => "",
                "TIME_OF_VACCINATION" => "12:05:20",
                "TRIAGED_BY" => "",
                "TRIAGE_DATE" => "",
                "TRIAGE_NOTES" => "",
                "TRIAGE_STATUS" => "",
                "VACCINATED" => "Y",
                "VACCINE_GIVEN" => vaccination_record.vaccine.upload_name,
                "YEAR_GROUP" => patient.year_group(academic_year:).to_s
              }
            )
          end
        end
      end

      context "with a deceased patient" do
        let(:session) { create(:session, programmes:, team:) }

        before do
          create(
            :patient,
            :vaccinated,
            :deceased,
            date_of_death: Date.new(2010, 1, 1),
            session:,
            programmes:
          )
        end

        it "includes the information" do
          expect(rows.first.to_hash).to include(
            "PERSON_DATE_OF_DEATH" => "2010-01-01"
          )
        end
      end

      context "with a restricted patient" do
        let(:session) { create(:session, programmes:, team:) }
        let(:patient) { create(:patient, :restricted, session:) }

        before do
          create(
            :vaccination_record,
            patient:,
            session:,
            programme:,
            performed_by: user
          )
        end

        it "doesn't include the address or postcode" do
          expect(rows.count).to eq(1)
          expect(rows.first["PERSON_ADDRESS_LINE_1"]).to be_blank
          expect(rows.first["PERSON_POSTCODE"]).to be_blank
        end
      end

      context "with a traced NHS number" do
        let(:session) { create(:session, programmes:, team:) }

        before do
          create(
            :patient,
            :vaccinated,
            updated_from_pds_at: Time.current,
            session:,
            programmes:
          )
        end

        it "includes the information" do
          expect(rows.first.to_hash).to include(
            "NHS_NUMBER_STATUS_CODE" => "01"
          )
        end
      end

      context "with a GP practice" do
        let(:gp_practice) do
          create(:gp_practice, name: "Practice", ods_code: "GP")
        end
        let(:session) { create(:session, programmes:, team:) }

        before do
          create(:patient, :vaccinated, gp_practice:, session:, programmes:)
        end

        it "includes the information" do
          expect(rows.first.to_hash).to include(
            "GP_NAME" => "Practice",
            "GP_ORGANISATION_CODE" => "GP"
          )
        end
      end

      context "with consent" do
        let(:session) { create(:session, programmes:, team:) }
        let(:patient) { create(:patient, :vaccinated, session:) }

        let!(:consent) do
          parent = create(:parent, full_name: "John Smith")
          create(:parent_relationship, :father, parent:, patient:)
          created_at = Time.zone.local(2024, 1, 1, 12, 5, 20)
          patient.programme_status(programme, academic_year:).update!(
            consent_status: "given",
            consent_vaccine_methods: %w[injection]
          )
          create(:consent, :given, patient:, parent:, programme:, created_at:)
        end

        it "includes the information" do
          expect(rows.first.to_hash).to include(
            "CONSENT_DETAILS" => "On 2024-01-01 at 12:05 GIVEN by John Smith",
            "CONSENT_STATUS" => expected_consent_status,
            "HEALTH_QUESTION_ANSWERS" =>
              consent
                .health_answers
                .map { "#{it.question} No from Dad" }
                .join("\r\n")
          )
        end
      end

      context "with a gillick assessment" do
        let(:session) { create(:session, programmes:, team:) }
        let(:patient) { create(:patient, :vaccinated, session:) }

        before do
          performed_by = create(:user, given_name: "Test", family_name: "Nurse")
          created_at = Date.new(2024, 1, 1)
          create(
            :gillick_assessment,
            :competent,
            patient:,
            session:,
            performed_by:,
            created_at:
          )
        end

        it "includes the information" do
          expect(rows.first.to_hash).to include(
            "GILLICK_ASSESSED_BY" => "NURSE, Test",
            "GILLICK_ASSESSMENT_DATE" => "2024-01-01",
            "GILLICK_ASSESSMENT_NOTES" => "Assessed as Gillick competent",
            "GILLICK_NOTIFY_PARENTS" => "",
            "GILLICK_STATUS" => "Gillick competent"
          )
        end

        context "when child doesn't want parents to be informed" do
          before do
            create(
              :consent,
              :self_consent,
              patient:,
              programme:,
              notify_parents_on_vaccination: false
            )
          end

          it "includes the information" do
            expect(rows.first.to_hash).to include(
              "GILLICK_NOTIFY_PARENTS" => "N"
            )
          end
        end

        context "when child wants parents to be informed" do
          before do
            create(
              :consent,
              :self_consent,
              patient:,
              programme:,
              notify_parents_on_vaccination: true
            )
          end

          it "includes the information" do
            expect(rows.first.to_hash).to include(
              "GILLICK_NOTIFY_PARENTS" => "Y"
            )
          end
        end
      end

      context "with a triage assessment" do
        let(:session) { create(:session, programmes:, team:) }
        let(:performed_by) do
          create(:user, given_name: "Test", family_name: "Nurse")
        end

        before do
          create(
            :patient,
            :consent_given_triage_safe_to_vaccinate,
            :vaccinated,
            session:,
            performed_by:
          )
        end

        it "includes the information" do
          expect(rows.first.to_hash).to include(
            "TRIAGED_BY" => "NURSE, Test",
            "TRIAGE_DATE" => Date.current.strftime("%Y-%m-%d"),
            "TRIAGE_NOTES" => "Okay to vaccinate",
            "TRIAGE_STATUS" => "Safe to vaccinate"
          )
        end
      end
    end
  end

  context "Flu programme" do
    let(:programme) { Programme.flu }
    let(:vaccine) { programme.vaccines.injection.sample }
    let(:expected_consent_status) { "Consent given for injection" }
    let(:expected_programme_name) { "Flu" }

    include_examples "generates a report"
  end

  context "HPV programme" do
    let(:programme) { Programme.hpv }
    let(:vaccine) { programme.vaccines.sample }
    let(:expected_consent_status) { "Consent given" }
    let(:expected_programme_name) { "HPV" }

    include_examples "generates a report"
  end

  context "MenACWY programme" do
    let(:programme) { Programme.menacwy }
    let(:vaccine) { programme.vaccines.sample }
    let(:expected_consent_status) { "Consent given" }
    let(:expected_programme_name) { "MenACWY" }

    include_examples "generates a report"
  end

  context "MMR(V) programme" do
    let(:programme) { Programme.mmr }
    let(:expected_consent_status) { "Consent given" }

    context "and an MMR vaccine" do
      let(:vaccine) { Vaccine.find_by!(brand: "Priorix") }
      let(:expected_programme_name) { "MMR" }

      include_examples "generates a report"
    end

    context "and an MMRV vaccine" do
      let(:vaccine) { Vaccine.find_by!(brand: "ProQuad") }
      let(:expected_programme_name) { "MMRV" }

      include_examples "generates a report"
    end
  end

  context "Td/IPV programme" do
    let(:programme) { Programme.td_ipv }
    let(:vaccine) { programme.vaccines.sample }
    let(:expected_consent_status) { "Consent given" }
    let(:expected_programme_name) { "Td/IPV" }

    include_examples "generates a report"
  end
end
