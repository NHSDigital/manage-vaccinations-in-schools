# frozen_string_literal: true

describe AppVaccinationRecordSummaryComponent do
  subject(:rendered) { render_inline(component) }

  let(:component) { described_class.new(vaccination_record, current_user:) }

  let(:current_user) { create(:user) }
  let(:performed_at) { Time.zone.local(2024, 9, 6, 12) }
  let(:outcome) { "administered" }
  let(:location) { create(:gias_school, name: "Hogwarts") }
  let(:programme) { Programme.hpv }
  let(:team) { create(:team, programmes: [programme]) }
  let(:session) { create(:session, programmes: [programme], location:, team:) }
  let(:patient) { create(:patient) }
  let(:vaccine) { programme.vaccines.find_by!(brand: "Gardasil 9") }
  let(:batch) do
    create(:batch, number: "ABC", expiry: Date.new(2026, 1, 1), vaccine:)
  end
  let(:other_batch) do
    create(:batch, number: "DEF", expiry: Date.new(2027, 1, 1), vaccine:)
  end
  let(:notes) { "Some notes." }
  let(:location_name) { nil }
  let(:protocol) { :pgd }
  let(:source) { "service" }
  let(:nhs_immunisations_api_id) { nil }

  let(:vaccination_record) do
    create(
      :vaccination_record,
      programme:,
      performed_at:,
      outcome:,
      batch:,
      vaccine:,
      patient:,
      session:,
      delivery_method: :intramuscular,
      delivery_site: :left_arm_upper_position,
      notes:,
      location:,
      location_name:,
      protocol:,
      pending_changes: {
        batch_number: other_batch&.number,
        batch_expiry: other_batch&.expiry,
        delivery_method: :nasal_spray,
        delivery_site: :nose
      },
      source:
    )
  end

  describe "outcome row" do
    it do
      expect(rendered).to have_css(
        ".nhsuk-summary-list__row",
        text: "OutcomeVaccinated"
      )
    end

    context "when not administered" do
      let(:outcome) { :unwell }

      it do
        expect(rendered).to have_css(
          ".nhsuk-summary-list__row",
          text: "OutcomeUnwell"
        )
      end
    end
  end

  describe "programme row" do
    it do
      expect(rendered).to have_css(
        ".nhsuk-summary-list__row",
        text: "ProgrammeHPV"
      )
    end
  end

  describe "vaccine row" do
    it do
      expect(rendered).to have_css(
        ".nhsuk-summary-list__row",
        text: "VaccineGardasil 9"
      )
    end

    context "without a vaccine" do
      let(:outcome) { :unwell }
      let(:vaccine) { nil }
      let(:batch) { nil }
      let(:other_batch) { nil }

      it { should_not have_css(".nhsuk-summary-list__row", text: "Vaccine") }
    end

    context "when manually reported that vaccination was already had" do
      let(:source) { "manual_report" }

      it { should_not have_css(".nhsuk-summary-list__row", text: "Vaccine") }
    end
  end

  describe "method row" do
    it do
      expect(rendered).to have_css(
        ".nhsuk-summary-list__row",
        text: "MethodIntramuscular"
      )
    end

    context "when manually reported that vaccination was already had" do
      let(:source) { "manual_report" }

      it do
        expect(rendered).not_to have_css(
          ".nhsuk-summary-list__row",
          text: "MethodIntramuscular"
        )
      end
    end
  end

  describe "site row" do
    it do
      expect(rendered).to have_css(
        ".nhsuk-summary-list__row",
        text: "SiteLeft arm (upper position)"
      )
    end

    context "when manually reported that vaccination was already had" do
      let(:source) { "manual_report" }

      it do
        expect(rendered).not_to have_css(
          ".nhsuk-summary-list__row",
          text: "MethodIntramuscular"
        )
      end
    end
  end

  describe "dose volume row" do
    it do
      expect(rendered).to have_css(
        ".nhsuk-summary-list__row",
        text: "Dose volume0.5 ml"
      )
    end

    context "without a vaccine" do
      let(:outcome) { :unwell }
      let(:vaccine) { nil }
      let(:batch) { nil }
      let(:other_batch) { nil }

      it do
        expect(rendered).not_to have_css(
          ".nhsuk-summary-list__row",
          text: "Dose volume"
        )
      end
    end

    context "with full_dose nil" do
      before { vaccination_record.update_columns(full_dose: nil) }

      it do
        expect(rendered).to have_css(
          ".nhsuk-summary-list__row",
          text: "Dose volumeUnknown"
        )
      end
    end

    context "when the vaccination record was sourced from a national reporting" do
      let(:vaccination_record) do
        create(:vaccination_record, :sourced_from_national_reporting)
      end

      it do
        expect(rendered).not_to have_css(
          ".nhsuk-summary-list__row",
          text: "Dose volume"
        )
      end
    end
  end

  describe "dose number row" do
    context "for an HPV programme" do
      context "and a unknown dose sequence" do
        before { vaccination_record.dose_sequence = nil }

        it { should have_content("Dose numberUnknown") }
      end

      context "and a specific dose sequence" do
        before { vaccination_record.dose_sequence = 2 }

        it { should have_content("Dose number2nd") }
      end
    end

    context "for an MMR programme" do
      let(:programme) { Programme.mmr }
      let(:vaccine) { programme.vaccines.find_by!(brand: "Priorix") }

      context "and a unknown dose sequence" do
        before { vaccination_record.dose_sequence = nil }

        it { should have_content("Dose numberUnknown") }
      end

      context "and a specific dose sequence" do
        before { vaccination_record.dose_sequence = 2 }

        it { should have_content("Dose number2nd") }

        context "when manually reported that vaccination was already had" do
          let(:source) { "manual_report" }

          it { should have_content("Dose number2nd") }
        end
      end
    end

    context "for a MenACWY programme" do
      let(:programme) { Programme.menacwy }
      let(:vaccine) { programme.vaccines.find_by!(brand: "MenQuadfi") }

      context "and a unknown dose sequence" do
        before { vaccination_record.dose_sequence = nil }

        it { should have_content("Dose numberUnknown") }
      end

      context "and a specific dose sequence" do
        before { vaccination_record.dose_sequence = 1 }

        it { should have_content("Dose number1st") }
      end
    end

    context "for a Td/IPV programme" do
      let(:programme) { Programme.td_ipv }
      let(:vaccine) { programme.vaccines.find_by!(brand: "Revaxis") }

      context "and a unknown dose sequence" do
        before { vaccination_record.dose_sequence = nil }

        it { should have_content("Dose numberUnknown") }
      end

      context "and a specific dose sequence" do
        before { vaccination_record.dose_sequence = 5 }

        it { should have_content("Dose number5th") }
      end
    end
  end

  describe "batch number row" do
    it { should have_css(".nhsuk-summary-list__row", text: "Batch numberABC") }

    context "without a vaccine" do
      let(:outcome) { :unwell }
      let(:vaccine) { nil }
      let(:batch) { nil }
      let(:other_batch) { nil }

      it do
        expect(rendered).not_to have_css(
          ".nhsuk-summary-list__row",
          text: "Batch number"
        )
      end
    end
  end

  describe "batch expiry date row" do
    it do
      expect(rendered).to have_css(
        ".nhsuk-summary-list__row",
        text: "Batch expiry date1 January 2026"
      )
    end

    context "without a vaccine" do
      let(:outcome) { :unwell }
      let(:vaccine) { nil }
      let(:batch) { nil }
      let(:other_batch) { nil }

      it do
        expect(rendered).not_to have_css(
          ".nhsuk-summary-list__row",
          text: "Batch expiry date"
        )
      end
    end
  end

  describe "date row" do
    it do
      expect(rendered).to have_css(
        ".nhsuk-summary-list__row",
        text: "Date6 September 2024"
      )
    end
  end

  describe "time row" do
    it do
      expect(rendered).to have_css(
        ".nhsuk-summary-list__row",
        text: "Time12:00pm"
      )
    end

    context "when the time is not specified" do
      let(:vaccination_record) do
        create(:vaccination_record, performed_at: Date.new(2020, 1, 1))
      end

      it do
        expect(rendered).to have_css(
          ".nhsuk-summary-list__row",
          text: "TimeUnknown"
        )
      end
    end
  end

  describe "vaccinator row" do
    context "when the user is present" do
      let(:vaccination_record) do
        create(
          :vaccination_record,
          performed_by: create(:user, given_name: "Test", family_name: "Nurse")
        )
      end

      it do
        expect(rendered).to have_css(
          ".nhsuk-summary-list__row",
          text: "VaccinatorNURSE, Test"
        )
      end
    end

    context "when the user is not present" do
      let(:vaccination_record) do
        create(
          :vaccination_record,
          performed_by: nil,
          performed_by_given_name: "Test",
          performed_by_family_name: "Nurse"
        )
      end

      it do
        expect(rendered).to have_css(
          ".nhsuk-summary-list__row",
          text: "VaccinatorNURSE, Test"
        )
      end
    end
  end

  describe "identity check row" do
    it do
      expect(rendered).not_to have_css(
        ".nhsuk-summary-list__row",
        text: "Child identified by"
      )
    end

    context "with an identity check" do
      before do
        create(:identity_check, :confirmed_by_patient, vaccination_record:)
      end

      it do
        expect(rendered).to have_css(
          ".nhsuk-summary-list__row",
          text: "Child identified byThe child"
        )
      end
    end
  end

  describe "location row" do
    it do
      expect(rendered).to have_css(
        ".nhsuk-summary-list__row",
        text: "LocationHogwarts"
      )
    end

    context "when the session took place in the generic clinic" do
      let(:session) do
        create(
          :session,
          programmes: [programme],
          location: create(:generic_clinic, team:),
          team:
        )
      end

      let(:location) { nil }
      let(:location_name) { "Hogwarts" }

      it do
        expect(rendered).to have_css(
          ".nhsuk-summary-list__row",
          text: "LocationHogwarts"
        )
      end
    end
  end

  describe "protocol row" do
    it do
      expect(rendered).to have_css(
        ".nhsuk-summary-list__row",
        text: "ProtocolPatient Group Direction (PGD)"
      )
    end

    context "when the vaccination record was sourced from a national reporting" do
      let(:vaccination_record) do
        create(:vaccination_record, :sourced_from_national_reporting)
      end

      it do
        expect(rendered).not_to have_css(
          ".nhsuk-summary-list__row",
          text: "Protocol"
        )
      end
    end
  end

  describe "notes row" do
    it do
      expect(rendered).to have_css(
        ".nhsuk-summary-list__row",
        text: "NotesSome notes."
      )
    end

    context "when the notes are not present" do
      let(:notes) { nil }

      it do
        expect(rendered).to have_css(
          ".nhsuk-summary-list__row",
          text: "NotesNot provided"
        )
      end
    end

    context "when the vaccination record was sourced from a national reporting" do
      let(:vaccination_record) do
        create(:vaccination_record, :sourced_from_national_reporting)
      end

      it do
        expect(rendered).not_to have_css(
          ".nhsuk-summary-list__row",
          text: "Notes"
        )
      end
    end
  end

  describe "source row" do
    it do
      expect(rendered).to have_css(
        ".nhsuk-summary-list__row",
        text: "SourceRecorded in Mavis"
      )
    end

    context "when the vaccination record was sourced from a national reporting" do
      let(:vaccination_record) do
        create(:vaccination_record, :sourced_from_national_reporting)
      end

      it do
        expect(rendered).to have_css(
          ".nhsuk-summary-list__row",
          text: "SourceMavis national reporting upload"
        )
      end
    end
  end

  describe "synced with NHS England row" do
    shared_examples "should have a `Synced with NHS England?` row" do
      it do
        expect(rendered).to have_css(
          ".nhsuk-summary-list__row",
          text: "Synced with NHS England?"
        )
      end
    end

    shared_examples "should not have a `Synced with NHS England?` row" do
      it do
        expect(rendered).not_to have_css(
          ".nhsuk-summary-list__row",
          text: "Synced with NHS England?"
        )
      end
    end

    before do
      Flipper.enable(:imms_api_integration)
      Flipper.enable(:imms_api_sync_job, programme)
    end

    after do
      Flipper.disable(:imms_api_integration)
      Flipper.disable(:imms_api_sync_job)
    end

    context "when the imms_api_integration and imms_api_sync_job feature flags are enabled" do
      it_behaves_like "should have a `Synced with NHS England?` row"
    end

    context "when the imms_api_integration feature flag is disabled" do
      before { Flipper.disable(:imms_api_integration) }

      it_behaves_like "should not have a `Synced with NHS England?` row"
    end

    context "when the imms_api_sync_job feature flag is disabled" do
      before { Flipper.disable(:imms_api_sync_job) }

      it_behaves_like "should not have a `Synced with NHS England?` row"
    end

    context "when the imms_api_sync_job feature flag is enabled for any programme" do
      before do
        Flipper.disable(:imms_api_sync_job)
        Flipper.enable(:imms_api_sync_job, Programme.flu)
      end

      it_behaves_like "should have a `Synced with NHS England?` row"
    end

    context "when the vaccination record was sourced from the API" do
      let(:vaccination_record) do
        create(
          :vaccination_record,
          :sourced_from_nhs_immunisations_api,
          programme:
        )
      end

      it_behaves_like "should not have a `Synced with NHS England?` row"
    end

    context "when the vaccination record was sourced from a historical upload" do
      let(:source) { "historical_upload" }
      let(:session) { nil }

      it_behaves_like "should not have a `Synced with NHS England?` row"
    end

    context "when the vaccination record was sourced from a national reporting upload and the flag is off" do
      let(:source) { "national_reporting" }
      let(:session) { nil }

      it_behaves_like "should not have a `Synced with NHS England?` row"
    end

    context "when the vaccination record was sourced from a national reporting upload and the flag is on" do
      before { Flipper.enable(:sync_national_reporting_to_imms_api) }

      let(:source) { "national_reporting" }
      let(:session) { nil }

      it_behaves_like "should have a `Synced with NHS England?` row"
    end
  end

  describe "with pending changes" do
    let(:component) do
      described_class.new(
        vaccination_record.with_pending_changes,
        current_user:
      )
    end

    it "highlights changed fields" do
      expect(rendered).to have_css(".app-highlight", text: "Nasal spray")
      expect(rendered).to have_css(".app-highlight", text: "Nose")
      expect(rendered).to have_css(".app-highlight", text: "DEF")
      expect(rendered).to have_css(".app-highlight", text: "1 January 2027")
    end
  end
end
