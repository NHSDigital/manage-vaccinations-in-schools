# frozen_string_literal: true

describe Reports::CareplusExporter do
  subject(:csv) do
    described_class.call(
      team:,
      programmes: [programme],
      academic_year:,
      start_date: 1.month.ago.to_date,
      end_date: Date.current,
      include_gender:,
      include_missing_nhs_number:,
      vaccine_columns:
    )
  end

  around { |example| travel_to(Date.new(2025, 8, 31)) { example.run } }

  let(:academic_year) { AcademicYear.current }
  let(:include_gender) { true }
  let(:include_missing_nhs_number) { true }
  let(:vaccine_columns) do
    %i[
      vaccine
      vaccine_code
      dose
      reason_not_given
      site
      manufacturer
      batch_number
    ]
  end

  let(:parsed_csv) { CSV.parse(csv) }
  let(:headers) { parsed_csv.first }
  let(:data_rows) { parsed_csv[1..] }

  shared_examples "generates a report" do
    let(:programmes) { [programme] }
    let(:team) do
      create(
        :team,
        careplus_staff_code: "ABCD",
        careplus_staff_type: "PQ",
        careplus_venue_code: "ABC",
        programmes:
      )
    end
    let(:location) do
      create(
        :gias_school,
        gias_local_authority_code: 123,
        gias_establishment_number: 456
      )
    end
    let(:session) { create(:session, team:, programmes:, location:) }

    it "includes the expected headers" do
      expect(headers).to include(
        "NHS Number",
        "Surname",
        "Forename",
        "Date of Birth",
        "Address Line 1",
        "Person Giving Consent",
        "Ethnicity",
        "Date Attended",
        "Time Attended",
        "Venue Type",
        "Venue Code",
        "Staff Type",
        "Staff Code",
        "Attended",
        "Reason Not Attended",
        "Suspension End Date",
        "Gender"
      )

      (1..5).each do |i|
        expect(headers).to include(
          "Vaccine #{i}",
          "Vaccine Code #{i}",
          "Dose #{i}",
          "Reason Not Given #{i}",
          "Site #{i}",
          "Manufacturer #{i}",
          "Batch No #{i}"
        )
      end
    end

    it "does not include the patient if they have no vaccination details" do
      create(:patient, session:)

      expect(data_rows.first).to be_nil
    end

    it "includes the patient and vaccination details" do
      patient =
        create(
          :patient,
          :consent_given_triage_not_needed,
          programmes:,
          session:
        )
      vaccination_record =
        create(
          :vaccination_record,
          programme:,
          vaccine:,
          delivery_method:,
          delivery_site: "left_arm_upper_position",
          patient:,
          session:,
          performed_at: 2.weeks.ago,
          dose_sequence: 1
        )

      attended_index = headers.index("Attended")
      vaccine_index = headers.index("Vaccine 1")
      vaccine_code_index = headers.index("Vaccine Code 1")
      dose_index = headers.index("Dose 1")
      batch_index = headers.index("Batch No 1")
      site_index = headers.index("Site 1")
      staff_type_index = headers.index("Staff Type")
      staff_code_index = headers.index("Staff Code")
      venue_type_index = headers.index("Venue Type")
      venue_code_index = headers.index("Venue Code")
      ethnicity_index = headers.index("Ethnicity")

      row = data_rows.first

      expect(row[attended_index]).to eq("Y")
      expect(row[vaccine_index]).to eq(
        vaccination_record.vaccine.snomed_product_code
      )
      expect(row[vaccine_code_index]).to eq(expected_vaccine_code)
      expect(row[dose_index]).to eq("1P")
      expect(row[batch_index]).to eq(vaccination_record.batch_number)
      expect(row[site_index]).to eq("ULA")
      expect(row[staff_type_index]).to eq("PQ")
      expect(row[staff_code_index]).to eq("ABCD")
      expect(row[venue_type_index]).to eq("SC")
      expect(row[venue_code_index]).to eq("123456")
      expect(row[ethnicity_index]).to be_blank
    end

    context "with multiple vaccination records for the same session on different dates" do
      let(:session) do
        create(
          :session,
          team:,
          programmes:,
          location:,
          dates: [4.weeks.ago.to_date, Date.current]
        )
      end

      let(:patient) do
        create(
          :patient,
          :consent_given_triage_not_needed,
          programmes:,
          session:
        )
      end

      before do
        create(
          :vaccination_record,
          programme:,
          delivery_method:,
          patient:,
          session:,
          performed_at: session.dates.first
        )
        create(
          :vaccination_record,
          programme:,
          delivery_method:,
          patient:,
          session:,
          performed_at: session.dates.last
        )
      end

      it "includes the vaccination details on separate rows" do
        expect(data_rows.count).to eq(2)

        date_attended_index = headers.index("Date Attended")

        expect(data_rows.first[date_attended_index]).to eq(
          session.dates.first.strftime("%d/%m/%Y")
        )
        expect(data_rows.second[date_attended_index]).to eq(
          session.dates.last.strftime("%d/%m/%Y")
        )
      end
    end

    context "in a community clinic" do
      let(:location) { create(:generic_clinic, team:) }

      it "includes clinic location details" do
        patient =
          create(
            :patient,
            :consent_given_triage_not_needed,
            programmes:,
            session:
          )
        create(
          :vaccination_record,
          programme:,
          patient:,
          session:,
          location_name: "A clinic"
        )

        venue_type_index = headers.index("Venue Type")
        venue_code_index = headers.index("Venue Code")

        row = data_rows.first

        expect(row[venue_type_index]).to eq("CL")
        expect(row[venue_code_index]).to eq("ABC")
      end
    end

    it "excludes vaccination records outside the date range" do
      patient = create(:patient, session:)

      create(
        :vaccination_record,
        programme:,
        patient:,
        session:,
        created_at: 2.months.ago,
        updated_at: 2.months.ago,
        performed_at: 2.months.ago
      )

      expect(data_rows.first).to be_nil
    end

    it "excludes vaccination records sourced manually" do
      patient = create(:patient, session:)

      create(
        :vaccination_record,
        :sourced_from_manual_report,
        programme:,
        patient:,
        session:
      )

      expect(data_rows.first).to be_nil
    end

    it "excludes not administered vaccination records" do
      patient = create(:patient, session:)

      create(
        :vaccination_record,
        :not_administered,
        programme:,
        patient:,
        session:
      )

      expect(data_rows.first).to be_nil
    end

    it "includes vaccination records updated within the date range" do
      patient = create(:patient, session:)

      create(
        :vaccination_record,
        programme:,
        patient:,
        session:,
        created_at: 2.months.ago,
        updated_at: 1.day.ago,
        performed_at: 2.months.ago
      )

      expect(data_rows.first).not_to be_nil
    end

    it "excludes vaccination records for a different programme outside the date range" do
      patient = create(:patient, session:)

      other_programme =
        Programme.find((Programme::TYPES - [programme.type]).sample)

      create(
        :vaccination_record,
        programme: other_programme,
        patient:,
        session:
      )

      expect(data_rows.first).to be_nil
    end

    context "with a session in a different team" do
      let(:session) { create(:session, programmes:, location:) }

      it "excludes the vaccination record" do
        create(:vaccination_record, programme:, session:)

        expect(data_rows.first).to be_nil
      end
    end

    context "with a restricted patient" do
      it "doesn't include the address line 1" do
        patient =
          create(
            :patient,
            :consent_given_triage_not_needed,
            programmes:,
            session:,
            restricted_at: Time.current
          )
        create(
          :vaccination_record,
          programme:,
          patient:,
          session:,
          performed_at: 2.weeks.ago
        )

        address_index = headers.index("Address Line 1")
        row = data_rows.first

        expect(row[0]).to eq(patient.nhs_number)
        expect(row).not_to be_nil
        expect(row[address_index]).to be_blank
      end
    end

    context "with a vaccination record that has no dose sequence" do
      it "includes the vaccination details" do
        patient = create(:patient, session:)
        create(
          :vaccination_record,
          programme:,
          patient:,
          session:,
          dose_sequence: nil
        )

        expect(data_rows.first[headers.index("Dose 1")]).to be_blank
      end
    end

    context "gender mapping" do
      {
        female: "F",
        male: "M",
        not_known: "U",
        not_specified: "I"
      }.each do |gender, expected_code|
        context "when the patient gender is #{gender}" do
          it "maps gender to #{expected_code}" do
            patient =
              create(
                :patient,
                :consent_given_triage_not_needed,
                programmes:,
                session:,
                gender_code: gender
              )
            create(
              :vaccination_record,
              programme:,
              patient:,
              session:,
              performed_at: 2.weeks.ago
            )

            gender_index = headers.index("Gender")
            expect(data_rows.first[gender_index]).to eq(expected_code)
          end
        end
      end
    end

    context "with a lower position anatomical site" do
      # The lower position anatomical site is still in the deltoid
      # so mapped to the upper arm code
      it "includes the vaccination details" do
        patient = create(:patient, session:)
        create(
          :vaccination_record,
          programme:,
          patient:,
          session:,
          delivery_site: "left_arm_lower_position"
        )

        expect(data_rows.first[headers.index("Site 1")]).to eq("ULA")
      end
    end
  end

  context "include_missing_nhs_number parameter" do
    let(:programme) { Programme.hpv }
    let(:team) { create(:team, programmes: [programme]) }
    let(:location) { create(:gias_school) }
    let(:session) do
      create(:session, team:, programmes: [programme], location:)
    end

    context "when true" do
      let(:include_missing_nhs_number) { true }

      it "includes patients without an NHS number" do
        patient =
          create(
            :patient,
            :consent_given_triage_not_needed,
            programmes: [programme],
            session:,
            nhs_number: nil
          )
        create(
          :vaccination_record,
          programme:,
          patient:,
          session:,
          performed_at: 2.weeks.ago
        )

        expect(data_rows.first).not_to be_nil
      end
    end

    context "when false" do
      let(:include_missing_nhs_number) { false }

      it "excludes patients without an NHS number" do
        patient =
          create(
            :patient,
            :consent_given_triage_not_needed,
            programmes: [programme],
            session:,
            nhs_number: nil
          )
        create(
          :vaccination_record,
          programme:,
          patient:,
          session:,
          performed_at: 2.weeks.ago
        )

        expect(data_rows.first).to be_nil
      end

      it "includes patients with an NHS number" do
        patient =
          create(
            :patient,
            :consent_given_triage_not_needed,
            programmes: [programme],
            session:
          )
        create(
          :vaccination_record,
          programme:,
          patient:,
          session:,
          performed_at: 2.weeks.ago
        )

        expect(data_rows.first).not_to be_nil
      end
    end
  end

  context "include_gender parameter" do
    let(:programme) { Programme.hpv }
    let(:team) { create(:team, programmes: [programme]) }
    let(:location) { create(:gias_school) }
    let(:session) do
      create(:session, team:, programmes: [programme], location:)
    end

    context "when true" do
      let(:include_gender) { true }

      it "includes the Gender header" do
        expect(headers).to include("Gender")
      end
    end

    context "when false" do
      let(:include_gender) { false }

      it "does not include the Gender header" do
        expect(headers).not_to include("Gender")
      end

      it "does not include the gender value in the row" do
        patient =
          create(
            :patient,
            :consent_given_triage_not_needed,
            programmes: [programme],
            session:,
            gender_code: :female
          )
        create(
          :vaccination_record,
          programme:,
          patient:,
          session:,
          performed_at: 2.weeks.ago
        )

        expect(data_rows.first.length).to eq(headers.length)
      end
    end
  end

  context "vaccine_columns parameter" do
    let(:programme) { Programme.hpv }
    let(:vaccine) { programme.vaccines.first }
    let(:team) { create(:team, programmes: [programme]) }
    let(:location) { create(:gias_school) }
    let(:session) do
      create(:session, team:, programmes: [programme], location:)
    end

    context "with a subset of columns" do
      let(:vaccine_columns) { %i[vaccine dose] }

      it "only includes headers for the specified columns" do
        (1..5).each do |i|
          expect(headers).to include("Vaccine #{i}", "Dose #{i}")
          expect(headers).not_to include(
            "Vaccine Code #{i}",
            "Reason Not Given #{i}",
            "Site #{i}",
            "Manufacturer #{i}",
            "Batch No #{i}"
          )
        end
      end

      it "includes the correct values for those columns" do
        patient =
          create(
            :patient,
            :consent_given_triage_not_needed,
            programmes: [programme],
            session:
          )
        create(
          :vaccination_record,
          programme:,
          vaccine:,
          patient:,
          session:,
          performed_at: 2.weeks.ago,
          dose_sequence: 1
        )

        row = data_rows.first
        expect(row[headers.index("Vaccine 1")]).to eq(
          vaccine.snomed_product_code
        )
        expect(row[headers.index("Dose 1")]).to eq("1P")
      end
    end

    context "with all columns" do
      let(:vaccine_columns) do
        %i[
          vaccine
          vaccine_code
          dose
          reason_not_given
          site
          manufacturer
          batch_number
        ]
      end

      it "includes headers for all columns" do
        (1..5).each do |i|
          expect(headers).to include(
            "Vaccine #{i}",
            "Vaccine Code #{i}",
            "Dose #{i}",
            "Reason Not Given #{i}",
            "Site #{i}",
            "Manufacturer #{i}",
            "Batch No #{i}"
          )
        end
      end

      it "includes the correct values for all columns" do
        patient =
          create(
            :patient,
            :consent_given_triage_not_needed,
            programmes: [programme],
            session:
          )
        create(
          :vaccination_record,
          programme:,
          vaccine:,
          delivery_method: :intramuscular,
          patient:,
          session:,
          performed_at: 2.weeks.ago,
          dose_sequence: 1
        )

        row = data_rows.first
        expect(row[headers.index("Vaccine 1")]).to eq(
          vaccine.snomed_product_code
        )
        expect(row[headers.index("Vaccine Code 1")]).to eq("HPV")
        expect(row[headers.index("Dose 1")]).to eq("1P")
        expect(row[headers.index("Reason Not Given 1")]).to eq("")
        expect(row[headers.index("Site 1")]).to eq("ULA")
        expect(row[headers.index("Manufacturer 1")]).to eq(vaccine.manufacturer)
        expect(row[headers.index("Batch No 1")]).not_to be_nil
      end
    end
  end

  context "Flu programme" do
    let(:programme) { Programme.flu }

    context "and an injected vaccine" do
      let(:vaccine) { programme.vaccines.injection.sample }
      let(:delivery_method) { :intramuscular }
      let(:expected_vaccine_code) { "FLU" }

      include_examples "generates a report"
    end

    context "and a nasal spray vaccine" do
      let(:vaccine) { programme.vaccines.nasal.sample }
      let(:delivery_method) { :nasal_spray }
      let(:expected_vaccine_code) { "FLUENZ" }

      include_examples "generates a report"
    end
  end

  context "HPV programme" do
    let(:programme) { Programme.hpv }
    let(:vaccine) { programme.vaccines.sample }
    let(:delivery_method) { :intramuscular }
    let(:expected_vaccine_code) { "HPV" }

    include_examples "generates a report"
  end

  context "MenACWY programme" do
    let(:programme) { Programme.menacwy }
    let(:vaccine) { programme.vaccines.sample }
    let(:delivery_method) { :intramuscular }
    let(:expected_vaccine_code) { "ACWYX4" }

    include_examples "generates a report"
  end

  context "MMR(V) programme" do
    let(:programme) { Programme.mmr }
    let(:delivery_method) { :intramuscular }

    context "and an MMR vaccine" do
      let(:vaccine) { Vaccine.find_by!(brand: "Priorix") }
      let(:expected_vaccine_code) { "MMR" }

      include_examples "generates a report"

      context "with a second dose vaccination record" do
        it "outputs 1B for the MMR dose sequence field" do
          patient = create(:patient, session:)
          create(
            :vaccination_record,
            programme:,
            vaccine:,
            patient:,
            session:,
            dose_sequence: 2
          )

          expect(data_rows.first[headers.index("Dose 1")]).to eq("1B")
        end
      end
    end

    context "and an MMRV vaccine" do
      let(:vaccine) { Vaccine.find_by!(brand: "ProQuad") }
      let(:expected_vaccine_code) { "MMRV" }

      include_examples "generates a report"
    end
  end

  context "Td/IPV programme" do
    let(:programme) { Programme.td_ipv }
    let(:vaccine) { programme.vaccines.sample }
    let(:delivery_method) { :intramuscular }
    let(:expected_vaccine_code) { "3IN1" }

    include_examples "generates a report"

    context "with a fifth dose vaccination record" do
      it "outputs 2B for the Td/IPV dose sequence field" do
        patient = create(:patient, session:)
        create(
          :vaccination_record,
          programme:,
          vaccine:,
          patient:,
          session:,
          dose_sequence: 5
        )

        expect(data_rows.first[headers.index("Dose 1")]).to eq("2B")
      end
    end
  end
end
