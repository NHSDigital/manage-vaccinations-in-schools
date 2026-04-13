# frozen_string_literal: true

# Normally we test this concern in isolation, but in this case it's bespoke to
# the VaccinationRecord and has a lot of dependencies on it, so not really
# worth it.
describe FHIRMapper::VaccinationRecord do
  let(:organisation) { create(:organisation) }
  let(:team) { create(:team, organisation:, programmes: [programme]) }
  let(:programme) { Programme.hpv }
  let(:school) { create(:gias_school, urn: "100006") }
  let(:session) do
    create(:session, location: school, programmes: [programme], team:)
  end
  let(:source) { "service" }
  let(:patient) { create(:patient, session:) }
  let(:vaccination_outcome) { :administered }
  let(:vaccine) { vaccination_record.vaccine }
  let(:nhs_immunisations_api_id) { nil }
  let(:nhs_immunisations_api_primary_source) { nil }
  let(:vaccination_record) do
    create(
      :vaccination_record,
      performed_ods_code: organisation.ods_code,
      patient:,
      programme:,
      session:,
      source:,
      vaccine: programme.vaccines.first,
      outcome: vaccination_outcome,
      nhs_immunisations_api_id:,
      nhs_immunisations_api_primary_source:
    )
  end
  let(:user) { vaccination_record.performed_by_user }

  describe "#fhir_record" do
    subject(:immunisation_fhir) { vaccination_record.fhir_record }

    describe "id" do
      subject { immunisation_fhir.id }

      context "when the vaccination record no UUID" do
        it { should be_nil }
      end

      context "when the vaccination record has a UUID" do
        let(:nhs_immunisations_api_id) { "1212-1212-1212-121212121212" }
        let(:nhs_immunisations_api_primary_source) { true }

        it { should eq "1212-1212-1212-121212121212" }
      end
    end

    describe "contained patient" do
      subject { immunisation_fhir.contained.find { it.id == "Patient1" } }

      it { should eq patient.fhir_record(reference_id: "Patient1") }
    end

    describe "patient reference" do
      subject { immunisation_fhir.patient.reference }

      it { should eq "#Patient1" }
    end

    describe "contained performing practitioner" do
      subject(:contained_practitioner) do
        immunisation_fhir.contained.find { it.id == "Practitioner1" }
      end

      it { should eq user.fhir_practitioner(reference_id: "Practitioner1") }

      context "when the performing professional is not a local user" do
        subject(:name) { contained_practitioner.name.first }

        before do
          vaccination_record.update(
            performed_by_user: nil,
            performed_by_given_name: "John",
            performed_by_family_name: "Howie"
          )
        end

        its(:given) { should eq ["John"] }
        its(:family) { should eq "Howie" }
      end

      context "when the performing professional is missing" do
        before { vaccination_record.update(performed_by_user: nil) }

        it { should be_nil }
      end
    end

    describe "performing practitioner" do
      subject do
        immunisation_fhir
          .performer
          .find { it.actor.type != "Organization" }
          .actor
          .reference
      end

      it { should eq "#Practitioner1" }
    end

    describe "identifier" do
      subject { immunisation_fhir.identifier.first }

      let(:mavis_system) do
        "http://manage-vaccinations-in-schools.nhs.uk/vaccination_records"
      end

      its(:value) { should eq vaccination_record.uuid }
      its(:system) { should eq mavis_system }

      context "when the vaccination record is from national reporting" do
        let(:national_reporting_test_ods_code) { "NR121" }
        let(:vaccination_record) do
          create(
            :vaccination_record,
            :sourced_from_national_reporting,
            uploaded_by: User.first,
            performed_ods_code: :national_reporting_test_ods_code,
            patient:,
            programme:,
            vaccine: programme.vaccines.first,
            outcome: "administered"
          )
        end

        let(:national_reporting_system) do
          "http://manage-vaccinations-in-schools.nhs.uk/national-reporting/vaccination-records"
        end

        its(:system) { should eq national_reporting_system }
      end
    end

    describe "vaccine code" do
      subject { immunisation_fhir.vaccineCode.coding.first }

      its(:code) { should eq vaccination_record.vaccine.snomed_product_code }
      its(:display) { should eq vaccination_record.vaccine.snomed_product_term }
      its(:system) { should eq "http://snomed.info/sct" }
    end

    describe "performing organisation" do
      subject do
        immunisation_fhir
          .performer
          .find { it.actor.type == "Organization" }
          .actor
      end

      let(:organisation_fhir_reference) do
        Organisation.fhir_reference(
          ods_code: vaccination_record.performed_ods_code
        )
      end

      it { should eq organisation_fhir_reference }
    end

    describe "status" do
      subject { immunisation_fhir.status }

      [
        { outcome: :administered, status: "completed" },
        { outcome: :refused, status: "not-done" },
        { outcome: :unwell, status: "not-done" },
        { outcome: :contraindicated, status: "not-done" },
        { outcome: :already_had, status: "not-done" }
      ].each do |test|
        context "when the vaccination record outcome is #{test[:outcome]}" do
          let(:vaccination_outcome) { test[:outcome] }

          it { should eq test[:status] }
        end
      end
    end

    describe "vaccination procedure" do
      subject(:vaccination_procedure) do
        immunisation_fhir.extension.find do
          it.url ==
            "https://fhir.hl7.org.uk/StructureDefinition/Extension-UKCore-VaccinationProcedure"
        end
      end

      it { should be_present }
      it { should be_a FHIR::Extension }

      describe "coding" do
        subject { vaccination_procedure.valueCodeableConcept.coding.first }

        its(:system) { should eq "http://snomed.info/sct" }
        its(:code) { should eq "761841000" }

        its(:display) do
          should eq "Administration of vaccine product containing only Human " \
                      "papillomavirus antigen"
        end
      end
    end

    describe "occurrenceDateTime" do
      subject { immunisation_fhir.occurrenceDateTime }

      it { should eq vaccination_record.performed_at.iso8601(3) }
    end

    describe "recorded" do
      subject { immunisation_fhir.recorded }

      it { should eq vaccination_record.created_at.iso8601(3) }
    end

    describe "primarySource" do
      subject { immunisation_fhir.primarySource }

      context "when the vaccination record is recorded in service" do
        it { should be true }
      end

      context "when the vaccination record was imported and has no session" do
        let(:session) { nil }
        let(:source) { "historical_upload" }

        it { should be false }
      end

      context "when the vaccination record was imported by a national reporting user" do
        let(:session) { nil }
        let(:source) { "national_reporting" }

        it { should be true }
      end
    end

    describe "manufacturer" do
      subject { immunisation_fhir.manufacturer }

      it { should eq vaccine.fhir_manufacturer_reference }
    end

    describe "location identifier" do
      subject { immunisation_fhir.location }

      it { should eq vaccination_record.location.fhir_reference }
    end

    describe "lotNumber" do
      subject { immunisation_fhir.lotNumber }

      it { should eq vaccination_record.batch_number }
    end

    describe "expirationDate" do
      subject { immunisation_fhir.expirationDate }

      it { should eq vaccination_record.batch_expiry.to_s }
    end

    describe "site" do
      subject(:site) { immunisation_fhir.site }

      it { should be_a FHIR::CodeableConcept }

      describe "site coding" do
        subject { site.coding.first }

        its(:code) { should eq "368208006" }
        its(:system) { should eq "http://snomed.info/sct" }

        its(:display) { should eq "Left upper arm structure" }
      end
    end

    describe "route" do
      subject(:route) { immunisation_fhir.route }

      it { should be_a FHIR::CodeableConcept }

      describe "route coding" do
        subject { route.coding.first }

        its(:code) { should eq "78421000" }
        its(:system) { should eq "http://snomed.info/sct" }
        its(:display) { should eq "Intramuscular" }
      end
    end

    describe "doseQuantity" do
      subject { immunisation_fhir.doseQuantity }

      it { should be_a FHIR::Quantity }
      its(:value) { should eq 0.5 } # Default dose quantity
      its(:unit) { should eq "ml" }
      its(:system) { should eq "http://snomed.info/sct" }
      its(:code) { should eq "258773002" }
    end

    describe "performer" do
      subject(:performer) { immunisation_fhir.performer }

      describe "user actor" do
        subject { performer.find { |p| p.actor.type != "Organization" }.actor }

        its(:reference) { should eq "#Practitioner1" }
      end

      describe "organisation actor" do
        subject { performer.find { |p| p.actor.type == "Organization" }.actor }

        it { should eq organisation.fhir_reference }
      end
    end

    describe "reasonCode" do
      subject(:route) { immunisation_fhir.reasonCode.sole }

      it { should be_a FHIR::CodeableConcept }

      describe "reasonCode coding" do
        subject { route.coding.first }

        its(:code) { should eq "723620004" }
        its(:system) { should eq "http://snomed.info/sct" }
      end
    end

    describe "protocolApplied" do
      subject(:protocol_applied) { immunisation_fhir.protocolApplied.sole }

      it { should be_a FHIR::Immunization::ProtocolApplied }

      describe "targetDisease" do
        subject(:target_disease) { protocol_applied.targetDisease }

        it { should eq programme.fhir_target_disease_coding }

        context "with an MMRV vaccination" do
          let(:programme) do
            Programme::Variant.new(Programme.mmr, variant_type: "mmrv")
          end

          describe "target disease coding has four items" do
            subject { programme.fhir_target_disease_coding.count }

            it { should eq 4 }
          end

          describe "measles coding" do
            subject { target_disease[0].coding.first }

            its(:code) { should eq "14189004" }
            its(:display) { should eq "Measles" }
            its(:system) { should eq "http://snomed.info/sct" }
          end

          describe "mumps coding" do
            subject { target_disease[1].coding.first }

            its(:code) { should eq "36989005" }
            its(:display) { should eq "Mumps" }
            its(:system) { should eq "http://snomed.info/sct" }
          end

          describe "rubella coding" do
            subject { target_disease[2].coding.first }

            its(:code) { should eq "36653000" }
            its(:display) { should eq "Rubella" }
            its(:system) { should eq "http://snomed.info/sct" }
          end

          describe "varicella coding" do
            subject { target_disease[3].coding.first }

            its(:code) { should eq "38907003" }
            its(:display) { should eq "Varicella" }
            its(:system) { should eq "http://snomed.info/sct" }
          end
        end
      end

      describe "doseNumberPositiveInt" do
        subject(:dose_number) { protocol_applied.doseNumberPositiveInt }

        it { should eq 1 }
      end
    end
  end

  describe "#from_fhir_record" do
    subject(:record) do
      VaccinationRecord.from_fhir_record(fhir_immunization, patient:)
    end

    around { |example| travel_to(Date.new(2025, 11, 20)) { example.run } }

    let(:fhir_immunization) do
      FHIR.from_contents(file_fixture(fixture_file_name).read)
    end

    let(:programme) { Programme.flu }

    shared_examples "a mapped vaccination record (common fields)" do
      its(:persisted?) { should be false }

      its(:nhs_immunisations_api_id) do
        should eq "11112222-3333-4444-5555-666677779999"
      end

      its(:source) { should eq "nhs_immunisations_api" }
      its(:nhs_immunisations_api_synced_at) { should eq Time.current }
      its(:programme) { should eq programme }

      context "when the record is saved to the database" do
        before { record.save! }

        its(:persisted?) { should be true }
        its(:uuid) { should be_present }
      end
    end

    context "for flu" do
      let(:programme) { Programme.flu }

      describe "the parsed full_dose value" do
        subject { record.full_dose }

        before do
          allow(fhir_immunization).to receive("doseQuantity").and_return(
            FHIR::R4::Quantity.new(
              value: dose_quantity,
              unit: "ml",
              system: "http://snomed.info/sct",
              code: "258773002"
            )
          )
        end

        let(:fixture_file_name) { "fhir/flu/fhir_record_half_dose.json" }

        context "when vaccine is nasal flu" do
          context "when dose quantity is 0.5" do
            let(:dose_quantity) { 0.5 }

            it { should be_nil }
          end

          context "when dose quantity is 0.075" do
            let(:dose_quantity) { 0.075 }

            it { should be_nil }
          end

          context "when dose quantity is 0.1" do
            let(:dose_quantity) { 0.1 }

            it { should be false }
          end

          context "when dose quantity is 0.2" do
            let(:dose_quantity) { 0.2 }

            it { should be true }
          end
        end

        context "when vaccine is not nasal flu" do
          before do
            # Injectable flu
            allow(fhir_immunization.vaccineCode.coding.first).to receive(
              "code"
            ).and_return("43207411000001105")
          end

          context "when dose quantity is 0.5" do
            let(:dose_quantity) { 0.5 }

            it { should be true }
          end

          context "when dose quantity is 0.075" do
            let(:dose_quantity) { 0.075 }

            it { should be true }
          end

          context "when dose quantity is 0.1" do
            let(:dose_quantity) { 0.1 }

            it { should be true }
          end

          context "when dose quantity is 0.2" do
            let(:dose_quantity) { 0.2 }

            it { should be true }
          end
        end
      end

      describe "dose sequence parsing" do
        subject { record.dose_sequence }

        let(:fixture_file_name) { "fhir/flu/fhir_record_full.json" }
        let(:dose_number_positive_int) { nil }
        let(:dose_number_string) { nil }

        before do
          allow(fhir_immunization.protocolApplied.sole).to receive_messages(
            doseNumberPositiveInt: dose_number_positive_int,
            doseNumberString: dose_number_string
          )
        end

        context "when both fields are nil" do
          it { should be_nil }

          it "does not include any dose notes" do
            expect(record.notes.to_s).not_to include("Reported dose number")
            expect(record.notes.to_s).not_to include(
              "Reported dose number string"
            )
          end
        end

        context "when doseNumberPositiveInt is within the maximum dose sequence for flu" do
          let(:dose_number_positive_int) { 1 }

          it { should eq 1 }

          it "does not include a dose sequence note" do
            expect(record.notes.to_s).not_to include("Reported dose number")
          end
        end

        context "when doseNumberPositiveInt exceeds the maximum dose sequence for flu" do
          let(:dose_number_positive_int) { 3 }

          it { should be_nil }

          it "records the out-of-range dose sequence in notes" do
            expect(record.notes.to_s).to include("Reported dose number: 3")
          end
        end

        context "when doseNumberPositiveInt is present and doseNumberString is also present" do
          let(:dose_number_positive_int) { 2 }
          let(:dose_number_string) { "first" }

          it { should eq 2 }

          it "does not include a dose number string note" do
            expect(record.notes.to_s).not_to include(
              "Reported dose number string"
            )
          end
        end

        context "when doseNumberString is an integer string" do
          let(:dose_number_string) { "1" }

          it { should eq 1 }

          it "does not include a dose number string note" do
            expect(record.notes.to_s).not_to include(
              "Reported dose number string"
            )
          end
        end

        context "when doseNumberString is a non-integer string" do
          let(:dose_number_string) { "first" }

          it { should be_nil }

          it "appends the value to notes" do
            expect(record.notes.to_s).to include(
              "Reported dose number string: first"
            )
          end
        end

        context "when doseNumberString is blank" do
          let(:dose_number_string) { "" }

          it { should be_nil }

          it "does not include a dose number string note" do
            expect(record.notes.to_s).not_to include(
              "Reported dose number string"
            )
          end
        end
      end

      describe "the parsed performed_ods_code value" do
        subject { record.performed_ods_code }

        before do
          allow(
            fhir_immunization
              .performer
              .find { it.actor&.type == "Organization" }
              .actor
              .identifier
          ).to receive(:value).and_return(ods_code)
        end

        let(:fixture_file_name) { "fhir/flu/fhir_record_full.json" }

        context "when the org performer ODS code is a real code" do
          let(:ods_code) { "B0C4P" }

          it { should eq "B0C4P" }
        end

        context "when the org performer ODS code is a placeholder" do
          let(:ods_code) { FHIRMapper::Location::UNKNOWN_IDENTIFIER }

          it { should be_nil }
        end
      end

      describe "the parsed batch_expiry value" do
        subject { record.batch_expiry }

        let(:fixture_file_name) { "fhir/flu/fhir_record_full.json" }

        before do
          allow(fhir_immunization).to receive(:expirationDate).and_return(
            expiration_date
          )
        end

        context "when the expiry date is realistic" do
          let(:expiration_date) { "2026-07-02" }

          it { should eq Date.new(2026, 7, 2) }
        end

        context "when the expiry date is after 2100" do
          let(:expiration_date) { "9999-12-31" }

          it { should be_nil }
        end

        context "when the expiry date is before 1900" do
          let(:expiration_date) { "1899-12-31" }

          it { should be_nil }
        end

        context "when the expiry date is nil" do
          let(:expiration_date) { nil }

          it { should be_nil }
        end
      end

      context "with a full fhir record" do
        let(:fixture_file_name) { "fhir/flu/fhir_record_full.json" }

        include_examples "a mapped vaccination record (common fields)"

        its(:nhs_immunisations_api_identifier_system) do
          should eq "https://supplierABC/identifiers/vacc"
        end

        its(:nhs_immunisations_api_identifier_value) do
          should eq "aaaabbbb-0000-1111-3333-ffff77773333"
        end

        its(:performed_by_given_name) { should eq "Steph" }
        its(:performed_by_family_name) { should eq "Smith" }
        its(:batch_number) { should eq "4120Z001" }
        its(:batch_expiry) { should eq Date.new(2026, 7, 2) }

        its(:vaccine) do
          should have_attributes(snomed_product_code: "43207411000001105")
        end

        its(:performed_at) { should eq Time.parse("2025-04-06T23:59:50+01:00") }
        its(:performed_at_date) { should eq Date.new(2025, 4, 6) }

        its(:performed_at_time) do
          should eq Time.new(2000, 1, 1, 23, 59, 50, "+00:00")
        end

        its(:delivery_method) { should eq "intramuscular" }
        its(:delivery_site) { should eq "left_arm_upper_position" }
        its(:full_dose) { should be true }
        its(:outcome) { should eq "administered" }
        its(:location) { should have_attributes(urn: "100006") }
        its(:location_name) { should be_nil }
        its(:performed_ods_code) { should eq "B0C4P" }
        its(:nhs_immunisations_api_primary_source) { should be true }

        its(:notes) do
          should eq "Performing organisation display name: Acme Healthcare"
        end

        its(:nhs_immunisations_api_snomed_procedure_code) do
          should eq "822851000000102"
        end

        its(:nhs_immunisations_api_snomed_procedure_term) do
          should eq "Seasonal influenza vaccination 111 (procedure)"
        end
      end

      context "with a record with not full dose" do
        let(:fixture_file_name) { "fhir/flu/fhir_record_half_dose.json" }

        include_examples "a mapped vaccination record (common fields)"

        its(:nhs_immunisations_api_identifier_system) do
          should eq "https://supplierABC/identifiers/vacc"
        end

        its(:nhs_immunisations_api_identifier_value) do
          should eq "aaaabbbb-0000-1111-3333-ffff77773333"
        end

        its(:performed_by_given_name) { should eq "Steph" }
        its(:performed_by_family_name) { should eq "Smith" }
        its(:batch_number) { should eq "4120Z001" }
        its(:batch_expiry) { should eq Date.new(2026, 7, 2) }

        its(:vaccine) do
          should have_attributes(snomed_product_code: "43208811000001106")
        end

        its(:performed_at) { should eq Time.parse("2025-04-06T23:59:50+01:00") }
        its(:performed_at_date) { should eq Date.new(2025, 4, 6) }

        its(:performed_at_time) do
          should eq Time.new(2000, 1, 1, 23, 59, 50, "+00:00")
        end

        its(:delivery_method) { should eq "nasal_spray" }
        its(:delivery_site) { should eq "nose" }
        its(:full_dose) { should be false }
        its(:outcome) { should eq "administered" }
        its(:location) { should have_attributes(urn: "100006") }
        its(:location_name) { should be_nil }
        its(:performed_ods_code) { should eq "B0C4P" }
        its(:nhs_immunisations_api_primary_source) { should be true }

        its(:notes) do
          should eq "Performing organisation display name: Acme Healthcare"
        end
      end

      context "with a record with an unexpected dose unit, and is nasal flu" do
        let(:fixture_file_name) do
          "fhir/flu/fhir_record_unexpected_dose_unit.json"
        end

        include_examples "a mapped vaccination record (common fields)"

        its(:nhs_immunisations_api_identifier_system) do
          should eq "https://supplierABC/identifiers/vacc"
        end

        its(:nhs_immunisations_api_identifier_value) do
          should eq "aaaabbbb-0000-1111-3333-ffff77773333"
        end

        its(:performed_by_given_name) { should eq "Steph" }
        its(:performed_by_family_name) { should eq "Smith" }
        its(:batch_number) { should eq "4120Z001" }
        its(:batch_expiry) { should eq Date.new(2026, 7, 2) }

        its(:vaccine) do
          should have_attributes(snomed_product_code: "43208811000001106")
        end

        its(:performed_at) { should eq Time.parse("2025-04-06T23:59:50+01:00") }
        its(:performed_at_date) { should eq Date.new(2025, 4, 6) }

        its(:performed_at_time) do
          should eq Time.new(2000, 1, 1, 23, 59, 50, "+00:00")
        end

        its(:delivery_method) { should eq "nasal_spray" }
        its(:delivery_site) { should eq "nose" }
        its(:full_dose) { should be_nil }
        its(:outcome) { should eq "administered" }
        its(:location) { should have_attributes(urn: "100006") }
        its(:location_name) { should be_nil }
        its(:performed_ods_code) { should eq "B0C4P" }

        its(:notes) do
          should eq "Performing organisation display name: Acme Healthcare"
        end
      end

      context "with a record with extended milliliter description" do
        let(:fixture_file_name) do
          "fhir/flu/fhir_record_extended_milliliter.json"
        end

        include_examples "a mapped vaccination record (common fields)"

        its(:nhs_immunisations_api_identifier_system) do
          should eq "https://nivs.ardengemcsu.nhs.uk/FluSAIS"
        end

        its(:nhs_immunisations_api_identifier_value) do
          should eq "https://nivs.ardengemcsu.nhs.uk/FluSAIS167327923"
        end

        its(:performed_by_given_name) { should be_nil }
        its(:performed_by_family_name) { should be_nil }
        its(:batch_number) { should eq "YF3276" }
        its(:batch_expiry) { should eq Date.new(2025, 12, 16) }

        its(:vaccine) do
          should have_attributes(snomed_product_code: "43208811000001106")
        end

        its(:performed_at) { should eq Time.parse("2025-09-30T00:00:00+00:00") }
        its(:performed_at_date) { should eq Date.new(2025, 9, 30) }

        its(:performed_at_time) do
          should eq Time.new(2000, 1, 1, 1, 0, 0, "+00:00")
        end

        its(:delivery_method) { should eq "nasal_spray" }
        its(:delivery_site) { should eq "nose" }
        its(:full_dose) { should be true }
        its(:outcome) { should eq "administered" }
        its(:location) { should have_attributes(urn: "100006") }
        its(:location_name) { should be_nil }
        its(:performed_ods_code) { should eq "B0C4P" }
        its(:nhs_immunisations_api_primary_source) { should be true }

        its(:nhs_immunisations_api_snomed_procedure_code) do
          should eq "955651000000100"
        end

        its(:nhs_immunisations_api_snomed_procedure_term) do
          should eq "Influenza vaccination given by other healthcare provider (situation)"
        end

        its(:notes) { should be_nil }
      end

      context "with a record that has an unknown vaccine" do
        let(:fixture_file_name) { "fhir/flu/fhir_record_unknown_vaccine.json" }

        include_examples "a mapped vaccination record (common fields)"

        its(:nhs_immunisations_api_identifier_system) do
          should eq "https://supplierABC/identifiers/vacc"
        end

        its(:nhs_immunisations_api_identifier_value) do
          should eq "aaaabbbb-0000-1111-3333-ffff77773333"
        end

        its(:vaccine) { should be_nil }
        its(:batch_number) { should eq "4120Z001" }
        its(:batch_expiry) { should eq Date.new(2026, 7, 2) }

        its(:performed_at) { should eq Time.parse("2025-04-06T23:59:50+01:00") }
        its(:performed_at_date) { should eq Date.new(2025, 4, 6) }

        its(:performed_at_time) do
          should eq Time.new(2000, 1, 1, 23, 59, 50, "+00:00")
        end

        its(:delivery_method) { should eq "intramuscular" }
        its(:delivery_site) { should eq "left_arm_upper_position" }
        its(:full_dose) { should be true }

        its(:location_name) { should eq "Unknown" }

        its(:outcome) { should eq "administered" }
        its(:performed_ods_code) { should eq "B0C4P" }
        its(:nhs_immunisations_api_primary_source) { should be true }

        its(:nhs_immunisations_api_snomed_procedure_code) do
          should eq "884861000000100"
        end

        its(:nhs_immunisations_api_snomed_procedure_term) do
          should eq "Administration of first intranasal seasonal influenza vaccination"
        end

        its(:notes) do
          should include(
                   "SNOMED product code: 43207411000001106",
                   "SNOMED description: Cell-based trivalent influenza vaccine"
                 )
        end
      end

      context "with a record from a GP which is very sparse" do
        let(:fixture_file_name) { "fhir/flu/fhir_record_gp.json" }

        include_examples "a mapped vaccination record (common fields)"

        its(:nhs_immunisations_api_identifier_system) { should eq "YGJ" }

        its(:nhs_immunisations_api_identifier_value) do
          should eq "046D1E37-C498-40E9-95FB-5E156F740804"
        end

        its(:vaccine) { should be_nil }
        its(:batch_number) { should be_nil }
        its(:batch_expiry) { should be_nil }

        its(:performed_at) { should eq Time.parse("2023-12-07T00:00:00+00:00") }
        its(:performed_at_date) { should eq Date.new(2023, 12, 7) }

        its(:performed_at_time) do
          should eq Time.new(2000, 1, 1, 0, 0, 0, "+00:00")
        end

        its(:delivery_method) { should be_nil }
        its(:delivery_site) { should be_nil }
        its(:full_dose) { should be true }
        its(:location_name) { should eq "B12345" }
        its(:outcome) { should eq "administered" }
        its(:performed_ods_code) { should eq "B12345" }
        its(:nhs_immunisations_api_primary_source) { should be false }

        its(:notes) do
          should include(
                   "Reported dose number string: Dose sequence not recorded"
                 )
        end

        its(:nhs_immunisations_api_snomed_procedure_code) do
          should eq "955651000000100"
        end

        its(:nhs_immunisations_api_snomed_procedure_term) do
          should eq "Influenza vaccination given by other healthcare provider (situation)"
        end
      end

      context "with a record that is nasal flu, and is missing dose quantity (from real GP)" do
        let(:fixture_file_name) do
          "fhir/flu/fhir_record_nasal_missing_dose.json"
        end

        include_examples "a mapped vaccination record (common fields)"

        its(:vaccine) do
          should have_attributes(snomed_product_code: "43208811000001106")
        end

        its(:performed_at) { should eq Time.parse("2025-10-06T00:00:00+00:00") }
        its(:performed_at_date) { should eq Date.new(2025, 10, 6) }

        its(:performed_at_time) do
          should eq Time.new(2000, 1, 1, 1, 0, 0, "+00:00")
        end

        its(:batch_number) { should be_nil }
        its(:batch_expiry) { should be_nil }
        its(:delivery_method) { should be_nil }
        its(:delivery_site) { should be_nil }
        its(:full_dose) { should be_nil }
        its(:location_name) { should eq "B12345" }
        its(:outcome) { should eq "administered" }
        its(:performed_ods_code) { should eq "B12345" }

        its(:nhs_immunisations_api_snomed_procedure_code) do
          should eq "884861000000100"
        end

        its(:nhs_immunisations_api_snomed_procedure_term) do
          should eq "Administration of first intranasal seasonal influenza vaccination"
        end

        its(:notes) { should be_nil }
      end

      context "with a record that is im flu, and is missing dose quantity" do
        let(:fixture_file_name) { "fhir/flu/fhir_record_im_missing_dose.json" }

        include_examples "a mapped vaccination record (common fields)"

        its(:vaccine) do
          should have_attributes(snomed_product_code: "43207411000001105")
        end

        its(:performed_at) { should eq Time.parse("2025-10-06T00:00:00+00:00") }
        its(:performed_at_date) { should eq Date.new(2025, 10, 6) }

        its(:performed_at_time) do
          should eq Time.new(2000, 1, 1, 1, 0, 0, "+00:00")
        end

        its(:batch_number) { should be_nil }
        its(:batch_expiry) { should be_nil }
        its(:delivery_method) { should be_nil }
        its(:delivery_site) { should be_nil }
        its(:full_dose) { should be true }
        its(:location_name) { should eq "B12345" }
        its(:outcome) { should eq "administered" }
        its(:performed_ods_code) { should eq "B12345" }

        its(:nhs_immunisations_api_snomed_procedure_code) do
          should eq "884861000000100"
        end

        its(:nhs_immunisations_api_snomed_procedure_term) do
          should eq "Administration of first intranasal seasonal influenza vaccination"
        end

        its(:notes) { should be_nil }
      end

      context "with a record with a short batch number" do
        let(:fixture_file_name) { "fhir/flu/fhir_record_short_batch.json" }

        include_examples "a mapped vaccination record (common fields)"

        its(:performed_by_given_name) { should be_nil }
        its(:performed_by_family_name) { should be_nil }
        its(:batch_number) { should eq "0" }
        its(:batch_expiry) { should be_nil }

        its(:vaccine) do
          should have_attributes(snomed_product_code: "43207411000001105")
        end

        its(:performed_at) { should eq Time.parse("2025-09-20T00:00:00+00:00") }
        its(:performed_at_date) { should eq Date.new(2025, 9, 20) }

        its(:performed_at_time) do
          should eq Time.new(2000, 1, 1, 1, 0, 0, "+00:00")
        end

        its(:delivery_method) { should eq "intramuscular" }
        its(:delivery_site) { should be_nil }
        its(:full_dose) { should be true }
        its(:outcome) { should eq "administered" }
        its(:location) { should be_nil }
        its(:location_name) { should eq "D83013" }
        its(:performed_ods_code) { should eq "D83013" }

        its(:nhs_immunisations_api_snomed_procedure_code) do
          should eq "985151000000100"
        end

        its(:nhs_immunisations_api_snomed_procedure_term) do
          should eq "Administration of first inactivated seasonal influenza vaccination"
        end

        its(:notes) { should be_nil }
      end

      context "with a record that has an unknown location" do
        let(:fixture_file_name) { "fhir/flu/fhir_record_unknown_location.json" }

        include_examples "a mapped vaccination record (common fields)"

        its(:nhs_immunisations_api_identifier_system) do
          should eq "http://manage-vaccinations-in-schools.nhs.uk/vaccination_records"
        end

        its(:nhs_immunisations_api_identifier_value) do
          should eq "68aef549-601f-427c-b914-7e459238c4dd"
        end

        its(:batch_number) { should eq "bb2222" }
        its(:batch_expiry) { should eq Date.new(2030, 1, 1) }

        its(:performed_at) { should eq Time.parse("2025-08-28T11:45:30+01:00") }
        its(:performed_at_date) { should eq Date.new(2025, 8, 28) }

        its(:performed_at_time) do
          should eq Time.new(2000, 1, 1, 11, 45, 30, "+00:00")
        end

        its(:delivery_method) { should eq "nasal_spray" }
        its(:delivery_site) { should eq "nose" }
        its(:full_dose) { should be true }
        its(:outcome) { should eq "administered" }
        its(:performed_ods_code) { should eq "A9A5A" }
        its(:nhs_immunisations_api_primary_source) { should be true }

        its(:location) { should be_nil }

        its(:location_name) { should eq "Unknown" }

        its(:nhs_immunisations_api_snomed_procedure_code) do
          should eq "884861000000100"
        end

        its(:nhs_immunisations_api_snomed_procedure_term) do
          should eq "Administration of first intranasal seasonal influenza vaccination"
        end

        its(:notes) { should be_nil }
      end

      context "with a record that is the minimum which can be created via the API" do
        let(:fixture_file_name) do
          "fhir/flu/fhir_record_minimum_api_create.json"
        end

        include_examples "a mapped vaccination record (common fields)"

        its(:nhs_immunisations_api_identifier_system) do
          should eq "https://www.ieds.england.nhs.uk/"
        end

        its(:nhs_immunisations_api_identifier_value) do
          should eq "7fa9ba01-aa9e-4ef9-a27c-30c9f413e421"
        end

        its(:batch_number) { should eq "aa1111" }
        its(:batch_expiry) { should eq Date.new(2030, 1, 1) }

        its(:performed_at) { should eq Time.parse("2025-10-06T07:57:32+01:00") }
        its(:performed_at_date) { should eq Date.new(2025, 10, 6) }

        its(:performed_at_time) do
          should eq Time.new(2000, 1, 1, 7, 57, 32, "+00:00")
        end

        its(:delivery_method) { should be_nil }
        its(:delivery_site) { should be_nil }
        its(:full_dose) { should be true }
        its(:outcome) { should eq "administered" }
        its(:performed_ods_code) { should eq "PERF" }

        its(:location) { should have_attributes(urn: "100006") }
        its(:location_name) { should be_nil }

        its(:nhs_immunisations_api_snomed_procedure_code) do
          should eq "884861000000100"
        end

        its(:nhs_immunisations_api_snomed_procedure_term) do
          should eq "Administration of first intranasal seasonal influenza vaccination"
        end

        its(:notes) { should be_nil }
      end

      context "with a record that is the minimum which can be created based on the spec (for CSV national reporting)" do
        let(:fixture_file_name) do
          "fhir/flu/fhir_record_minimum_national_reporting_spec.json"
        end

        include_examples "a mapped vaccination record (common fields)"

        its(:nhs_immunisations_api_identifier_system) { should eq "YGJ" }

        its(:nhs_immunisations_api_identifier_value) do
          should eq "046D1E37-C498-40E9-95FB-5E156F740804"
        end

        its(:vaccine) { should be_nil }
        its(:batch_number) { should be_nil }
        its(:batch_expiry) { should be_nil }

        its(:performed_at) { should eq Time.parse("2023-12-07T00:00:00+00:00") }
        its(:performed_at_date) { should eq Date.new(2023, 12, 7) }

        its(:performed_at_time) do
          should eq Time.new(2000, 1, 1, 0, 0, 0, "+00:00")
        end

        its(:delivery_method) { should be_nil }
        its(:delivery_site) { should be_nil }
        its(:full_dose) { should be true }
        its(:location_name) { should eq "B12345" }
        its(:outcome) { should eq "administered" }
        its(:performed_ods_code) { should eq "B12345" }

        its(:notes) do
          should include(
                   "Reported dose number string: Dose sequence not recorded"
                 )
        end

        its(:nhs_immunisations_api_snomed_procedure_code) { should be_nil }
        its(:nhs_immunisations_api_snomed_procedure_term) { should be_nil }
      end
    end

    context "for hpv" do
      let(:programme) { Programme.hpv }

      context "with a fhir record from Mavis" do
        let(:fixture_file_name) { "fhir/hpv/fhir_record_from_mavis.json" }

        include_examples "a mapped vaccination record (common fields)"

        its(:nhs_immunisations_api_identifier_system) do
          should eq "http://manage-vaccinations-in-schools.nhs.uk/vaccination_records"
        end

        its(:nhs_immunisations_api_identifier_value) do
          should eq "aaaabbbb-0000-1111-3333-ffff77773333"
        end

        its(:performed_by_given_name) { should be_nil }
        its(:performed_by_family_name) { should be_nil }
        its(:batch_number) { should eq "GU9271" }
        its(:batch_expiry) { should eq Date.new(2025, 12, 2) }

        its(:vaccine) do
          should have_attributes(snomed_product_code: "33493111000001108")
        end

        its(:performed_at) { should eq Time.parse("2025-11-03T15:30:34+00:00") }
        its(:performed_at_date) { should eq Date.new(2025, 11, 3) }

        its(:performed_at_time) do
          should eq Time.new(2000, 1, 1, 15, 30, 34, "+00:00")
        end

        its(:delivery_method) { should eq "intramuscular" }
        its(:delivery_site) { should eq "left_arm_upper_position" }
        its(:full_dose) { should be true }
        its(:outcome) { should eq "administered" }
        its(:location) { should have_attributes(urn: "100006") }
        its(:location_name) { should be_nil }
        its(:performed_ods_code) { should eq "R1L" }
        its(:nhs_immunisations_api_primary_source) { should be true }

        its(:nhs_immunisations_api_snomed_procedure_code) do
          should eq "761841000"
        end

        its(:nhs_immunisations_api_snomed_procedure_term) do
          should eq "Administration of vaccine product containing only Human papillomavirus antigen (procedure)"
        end

        its(:notes) { should be_nil }
      end
    end

    context "for menacwy" do
      let(:programme) { Programme.menacwy }

      context "with a fhir record from Mavis" do
        let(:fixture_file_name) { "fhir/menacwy/fhir_record_from_mavis.json" }

        include_examples "a mapped vaccination record (common fields)"

        its(:nhs_immunisations_api_identifier_system) do
          should eq "http://manage-vaccinations-in-schools.nhs.uk/vaccination_records"
        end

        its(:nhs_immunisations_api_identifier_value) do
          should eq "aaaabbbb-0000-1111-3333-ffff77773333"
        end

        its(:performed_by_given_name) { should be_nil }
        its(:performed_by_family_name) { should be_nil }
        its(:batch_number) { should eq "TK6780" }
        its(:batch_expiry) { should eq Date.new(2025, 11, 20) }

        its(:vaccine) do
          should have_attributes(snomed_product_code: "39779611000001104")
        end

        its(:performed_at) { should eq Time.parse("2025-11-03T15:31:07+00:00") }
        its(:performed_at_date) { should eq Date.new(2025, 11, 3) }

        its(:performed_at_time) do
          should eq Time.new(2000, 1, 1, 15, 31, 7, "+00:00")
        end

        its(:delivery_method) { should eq "intramuscular" }
        its(:delivery_site) { should eq "left_arm_upper_position" }
        its(:full_dose) { should be true }
        its(:outcome) { should eq "administered" }
        its(:location) { should have_attributes(urn: "100006") }
        its(:location_name) { should be_nil }
        its(:performed_ods_code) { should eq "R1L" }
        its(:nhs_immunisations_api_primary_source) { should be true }

        its(:notes) { should include("Reported dose number string: Unknown") }

        its(:nhs_immunisations_api_snomed_procedure_code) do
          should eq "871874000"
        end

        its(:nhs_immunisations_api_snomed_procedure_term) do
          should eq "Administration of vaccine product containing only " \
                      "Neisseria meningitidis serogroup A, C, W135 and Y " \
                      "antigens (procedure)"
        end
      end
    end

    context "for td_ipv" do
      let(:programme) { Programme.td_ipv }

      context "with a fhir record from Mavis" do
        let(:fixture_file_name) { "fhir/td_ipv/fhir_record_from_mavis.json" }

        include_examples "a mapped vaccination record (common fields)"

        its(:nhs_immunisations_api_identifier_system) do
          should eq "http://manage-vaccinations-in-schools.nhs.uk/vaccination_records"
        end

        its(:nhs_immunisations_api_identifier_value) do
          should eq "aaaabbbb-0000-1111-3333-ffff77773333"
        end

        its(:performed_by_given_name) { should be_nil }
        its(:performed_by_family_name) { should be_nil }
        its(:batch_number) { should eq "SP3485" }
        its(:batch_expiry) { should eq Date.new(2025, 12, 9) }

        its(:vaccine) do
          should have_attributes(snomed_product_code: "7374511000001107")
        end

        its(:performed_at) { should eq Time.parse("2025-11-03T15:31:37+00:00") }
        its(:performed_at_date) { should eq Date.new(2025, 11, 3) }

        its(:performed_at_time) do
          should eq Time.new(2000, 1, 1, 15, 31, 37, "+00:00")
        end

        its(:delivery_method) { should eq "intramuscular" }
        its(:delivery_site) { should eq "left_arm_upper_position" }
        its(:full_dose) { should be true }
        its(:outcome) { should eq "administered" }
        its(:location) { should have_attributes(urn: "100006") }
        its(:location_name) { should be_nil }
        its(:performed_ods_code) { should eq "R1L" }
        its(:nhs_immunisations_api_primary_source) { should be true }

        its(:notes) { should include("Reported dose number string: Unknown") }

        its(:nhs_immunisations_api_snomed_procedure_code) do
          should eq "866186002"
        end

        its(:nhs_immunisations_api_snomed_procedure_term) do
          should eq "Administration of vaccine product containing only " \
                      "Clostridium tetani and Corynebacterium diphtheriae " \
                      "and Human poliovirus antigens (procedure)"
        end
      end
    end

    context "for mmr" do
      let(:programme) do
        Programme::Variant.new(Programme.mmr, variant_type: "mmr")
      end

      context "with a fhir record from Mavis" do
        let(:fixture_file_name) { "fhir/mmr/fhir_record_from_mavis.json" }

        include_examples "a mapped vaccination record (common fields)"

        its(:programme) { should eq programme }

        its(:nhs_immunisations_api_identifier_system) do
          should eq "http://manage-vaccinations-in-schools.nhs.uk/vaccination_records"
        end

        its(:nhs_immunisations_api_identifier_value) do
          should eq "aaaabbbb-0000-1111-3333-ffff77773333"
        end

        its(:performed_by_given_name) { should be_nil }
        its(:performed_by_family_name) { should be_nil }
        its(:batch_number) { should eq "ABC123" }
        its(:batch_expiry) { should eq Date.new(2025, 11, 10) }

        its(:vaccine) do
          should have_attributes(snomed_product_code: "13968211000001108")
        end

        its(:performed_at) { should eq Time.parse("2025-11-03T15:11:11+00:00") }
        its(:performed_at_date) { should eq Date.new(2025, 11, 3) }

        its(:performed_at_time) do
          should eq Time.new(2000, 1, 1, 15, 11, 11, "+00:00")
        end

        its(:delivery_method) { should eq "intramuscular" }
        its(:delivery_site) { should eq "left_arm_upper_position" }
        its(:full_dose) { should be true }
        its(:outcome) { should eq "administered" }
        its(:location) { should have_attributes(urn: "100006") }
        its(:location_name) { should be_nil }
        its(:performed_ods_code) { should eq "R1L" }
        its(:nhs_immunisations_api_primary_source) { should be true }

        its(:notes) { should include("Reported dose number string: Unknown") }

        its(:nhs_immunisations_api_snomed_procedure_code) do
          should eq "38598009"
        end

        its(:nhs_immunisations_api_snomed_procedure_term) do
          should eq "Administration of vaccine product containing only " \
                      "Measles morbillivirus and Mumps orthorubulavirus " \
                      "and Rubella virus antigens (procedure)"
        end
      end
    end

    context "for mmrv" do
      let(:programme) do
        Programme::Variant.new(Programme.mmr, variant_type: "mmrv")
      end

      context "with a fhir record from Mavis" do
        let(:fixture_file_name) { "fhir/mmrv/fhir_record_from_mavis.json" }

        include_examples "a mapped vaccination record (common fields)"

        its(:programme) { should eq programme }

        its(:nhs_immunisations_api_identifier_system) do
          should eq "http://manage-vaccinations-in-schools.nhs.uk/vaccination_records"
        end

        its(:nhs_immunisations_api_identifier_value) do
          should eq "aaaabbbb-0000-1111-3333-ffff77773333"
        end

        its(:performed_by_given_name) { should be_nil }
        its(:performed_by_family_name) { should be_nil }
        its(:batch_number) { should eq "XKCD1234" }
        its(:batch_expiry) { should eq Date.new(2026, 11, 10) }

        its(:vaccine) do
          should have_attributes(snomed_product_code: "45525711000001102")
        end

        its(:performed_at) { should eq Time.parse("2025-01-27T08:49:44+0000") }
        its(:performed_at_date) { should eq Date.new(2025, 1, 27) }

        its(:performed_at_time) do
          should eq Time.new(2000, 1, 1, 8, 49, 44, "+00:00")
        end

        its(:delivery_method) { should eq "intramuscular" }
        its(:delivery_site) { should eq "left_arm_upper_position" }
        its(:full_dose) { should be true }
        its(:outcome) { should eq "administered" }
        its(:location) { should have_attributes(urn: "100006") }
        its(:location_name) { should be_nil }
        its(:performed_ods_code) { should eq "R1L" }
        its(:nhs_immunisations_api_primary_source) { should be true }

        its(:notes) { should include("Reported dose number string: Unknown") }

        its(:nhs_immunisations_api_snomed_procedure_code) do
          should eq "432636005"
        end

        its(:nhs_immunisations_api_snomed_procedure_term) do
          should eq "Administration of vaccine product containing only " \
                      "Human alphaherpesvirus 3 and Measles morbillivirus " \
                      "and Mumps orthorubulavirus and Rubella virus antigens"
        end
      end
    end
  end
end
