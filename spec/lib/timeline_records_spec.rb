# frozen_string_literal: true

describe TimelineRecords do
  subject(:timeline) do
    described_class.new(patient, details_config:, show_pii:)
  end

  let(:programme) { Programme.hpv }
  let(:details_config) { TimelineRecords::DEFAULT_DETAILS_CONFIG }
  let(:show_pii) { false }
  let(:team) { create(:team, programmes: [programme]) }
  let(:session) { create(:session, team:, programmes: [programme]) }
  let(:class_import) { create(:class_import, session:) }
  let(:cohort_import) { create(:cohort_import, team:) }
  let(:cohort_import_additional) { create(:cohort_import, team:) }
  let(:class_import_additional) { create(:class_import, session:) }
  let(:user) { create(:user) }
  let(:patient) do
    create(
      :patient,
      given_name: "Alex",
      year_group: 8,
      address_postcode: "SW1A 1AA",
      class_imports: [class_import],
      team:
    )
  end
  let(:school_move) { create(:school_move, :to_school, patient:) }
  let(:school_move_log_entry) { create(:school_move_log_entry, patient:) }
  let(:triage) do
    create(
      :triage,
      :safe_to_vaccinate,
      patient:,
      programme:,
      performed_by: user
    )
  end
  let(:consent) do
    create(
      :consent,
      patient:,
      response: :given,
      programme:,
      created_at: Date.new(2025, 1, 1)
    )
  end
  let(:second_consent) do
    create(
      :consent,
      patient:,
      response: :given,
      programme:,
      created_at: Date.new(2025, 2, 1)
    )
  end
  let(:third_consent) do
    create(
      :consent,
      patient:,
      response: :given,
      programme:,
      created_at: Date.new(2025, 3, 1)
    )
  end
  let(:fourth_consent) do
    create(
      :consent,
      patient:,
      response: :given,
      programme:,
      created_at: Date.new(2025, 4, 1)
    )
  end
  let(:consent_audit) do
    consent.audits.create!(
      audited_changes: {
        response: %w[nil given]
      },
      associated_type: Patient,
      associated_id: patient.id
    )
  end
  let(:vaccination_record) do
    create(
      :vaccination_record,
      patient:,
      programme:,
      session:,
      created_at: Date.new(2025, 1, 1)
    )
  end
  let(:second_vaccination_record) do
    create(
      :vaccination_record,
      patient:,
      programme:,
      session:,
      created_at: Date.new(2025, 2, 1)
    )
  end
  let(:third_vaccination_record) do
    create(
      :vaccination_record,
      patient:,
      programme:,
      session:,
      created_at: Date.new(2025, 3, 1)
    )
  end
  let(:fourth_vaccination_record) do
    create(
      :vaccination_record,
      patient:,
      programme:,
      session:,
      created_at: Date.new(2025, 4, 1)
    )
  end

  describe "#load_events" do
    before do
      patient.triages << triage
      patient.consents << consent
      create(:patient_location, patient:, location: session.location, session:)
      patient.school_moves << school_move
      patient.school_move_log_entries << school_move_log_entry
      patient.vaccination_records << vaccination_record
      patient.cohort_imports << cohort_import
    end

    context "with default details configuration" do
      it "loads consent events with default fields" do
        timeline.send(:load_events, ["consents"])
        expect(timeline.instance_variable_get(:@events).size).to eq 1
        event = timeline.instance_variable_get(:@events).first
        expect(event[:event_type]).to eq "Consent"
        expect(event[:details]).to eq(
          {
            "programme_type" => consent.programme_type,
            "response" => consent.response,
            "route" => consent.route
          }
        )
      end

      it "loads triage events with default fields" do
        timeline.send(:load_events, ["triages"])
        expect(timeline.instance_variable_get(:@events).size).to eq 1
        event = timeline.instance_variable_get(:@events).first
        expect(event[:event_type]).to eq "Triage"
        expect(event[:details]).to eq(
          { "status" => triage.status, "performed_by_user_id" => user.id }
        )
      end

      it "loads cohort_import events with default fields" do
        timeline.send(:load_events, ["cohort_imports"])
        expect(timeline.instance_variable_get(:@events).size).to eq 1
        event = timeline.instance_variable_get(:@events).first
        expect(event[:event_type]).to eq "CohortImport"
        expect(event[:details]).to eq({})
      end

      it "loads class_import events with default fields" do
        timeline.send(:load_events, ["class_imports"])
        expect(timeline.instance_variable_get(:@events).size).to eq 1
        event = timeline.instance_variable_get(:@events).first
        expect(event[:event_type]).to eq "ClassImport"
        expect(event[:details]).to eq({})
      end

      it "loads school_move events with default fields" do
        timeline.send(:load_events, ["school_moves"])
        expect(timeline.instance_variable_get(:@events).size).to eq 1
        event = timeline.instance_variable_get(:@events).first
        expect(event[:event_type]).to eq "SchoolMove"
        expect(event[:details]).to eq(
          {
            "school_id" => school_move.school_id,
            "source" => school_move.source
          }
        )
      end

      it "loads school_move_log_entry events with default fields" do
        timeline.send(:load_events, ["school_move_log_entries"])
        expect(timeline.instance_variable_get(:@events).size).to eq 1
        event = timeline.instance_variable_get(:@events).first
        expect(event[:event_type]).to eq "SchoolMoveLogEntry"
        expect(event[:details]).to eq(
          {
            "school_id" => school_move_log_entry.school_id,
            "user_id" => school_move_log_entry.user_id
          }
        )
      end

      it "loads vaccination events with default fields" do
        timeline.send(:load_events, ["vaccination_records"])
        expect(timeline.instance_variable_get(:@events).size).to eq 1
        event = timeline.instance_variable_get(:@events).first
        expect(event[:event_type]).to eq "VaccinationRecord"
        expect(event[:details]).to eq(
          {
            "outcome" => vaccination_record.outcome,
            "session_id" => vaccination_record.session_id
          }
        )
      end
    end

    context "with custom details configuration" do
      let(:details_config) { { consents: %i[route], triages: %i[status] } }

      before do
        patient.consents << consent
        patient.triages << triage
      end

      it "loads consent events with custom fields" do
        timeline.send(:load_events, ["consents"])
        expect(timeline.instance_variable_get(:@events).size).to eq 1
        event = timeline.instance_variable_get(:@events).first
        expect(event[:event_type]).to eq "Consent"
        expect(event[:details]).to eq({ "route" => consent.route })
      end

      it "loads triage events with custom fields" do
        timeline.send(:load_events, ["triages"])
        expect(timeline.instance_variable_get(:@events).size).to eq 1
        event = timeline.instance_variable_get(:@events).first
        expect(event[:event_type]).to eq "Triage"
        expect(event[:details]).to eq({ "status" => triage.status })
      end
    end

    context "with custom event handler" do
      before do
        patient.cohort_imports = [cohort_import]
        additional_events = {
          class_imports: {
            session.id => [class_import_additional.id]
          },
          cohort_imports: [cohort_import_additional.id]
        }
        timeline.instance_variable_set(:@additional_events, additional_events)
      end

      it "calls custom event handler for add_class_imports" do
        timeline.send(:load_events, ["add_class_imports_#{session.id}"])
        expect(timeline.instance_variable_get(:@events).size).to eq 1
        event = timeline.instance_variable_get(:@events).first
        expect(event[:event_type]).to eq "ClassImport"
        expect(event[:id]).to eq class_import_additional.id
        expect(event[:details]).to eq(
          { location_id: "#{session.location.id}, excluding patient" }
        )
      end

      it "calls custom event handler for org_cohort_imports" do
        timeline.send(:load_events, ["org_cohort_imports"])
        expect(timeline.instance_variable_get(:@events).size).to eq 1
        event = timeline.instance_variable_get(:@events).first
        expect(event[:event_type]).to eq "CohortImport"
        expect(event[:id]).to eq cohort_import_additional.id
        expect(event[:details]).to eq "excluding patient"
      end
    end
  end

  describe "#load_add_class_imports_events" do
    before do
      create(:patient_location, patient:, location: session.location, session:)
      additional_events = {
        class_imports: {
          session.id => [class_import_additional.id]
        }
      }
      timeline.instance_variable_set(:@additional_events, additional_events)
    end

    it "returns an array of events" do
      events = timeline.send(:load_events, ["add_class_imports_#{session.id}"])
      expect(events).to be_an Array
    end

    it "includes the class import event" do
      events = timeline.send(:load_events, ["add_class_imports_#{session.id}"])
      expect(events.size).to eq 1
      event = events.first
      expect(event[:event_type]).to eq "ClassImport"
      expect(event[:id]).to eq class_import_additional.id
      expect(event[:details]).to eq(
        { location_id: "#{session.location.id}, excluding patient" }
      )
      expect(event[:created_at]).to eq class_import_additional.created_at
    end

    it "handles multiple additional class imports" do
      another_additional_class_import =
        create(:class_import, session:, created_at: 1.minute.from_now)
      additional_events = {
        class_imports: {
          session.id => [
            class_import_additional.id,
            another_additional_class_import.id
          ]
        }
      }
      timeline.instance_variable_set(:@additional_events, additional_events)
      events = timeline.send(:load_events, ["add_class_imports_#{session.id}"])
      expect(events.size).to eq 2
      expect(events.map { |event| event[:id] }).to contain_exactly(
        class_import_additional.id,
        another_additional_class_import.id
      )
    end

    it "handles no additional class imports" do
      additional_events = { class_imports: { session.id => [] } }
      timeline.instance_variable_set(:@additional_events, additional_events)
      events = timeline.send(:load_events, ["add_class_imports_#{session.id}"])
      expect(events).to be_empty
    end

    it "handles a nil session id" do
      output =
        capture_error { timeline.send(:load_events, ["add_class_imports_nil"]) }
      expect(output).to eq("No handler for event type: add_class_imports_nil\n")
      expect(timeline.instance_variable_get(:@events)).to be_empty
    end
  end

  describe "#audits_events" do
    before do
      create(:patient_location, patient:, location: session.location, session:)
    end

    context "with default settings" do
      let(:timeline) { described_class.new(patient) }

      it "returns an array of events" do
        patient.audits.create!(
          audited_changes: {
            team_id: [nil, 1],
            given_name: %w[Alessia Alice]
          }
        )
        events = timeline.load_events(["audits"])
        expect(events).to be_an Array
      end

      it "includes the audit event" do
        patient.audits.create!(
          audited_changes: {
            team_id: [nil, 1],
            given_name: %w[Alessia Alice]
          }
        )
        events = timeline.load_events(["audits"])
        expect(events.size).to eq 3 # create is the first audit, PatientSession-Audit is the second
        event = events.first
        expect(event[:event_type]).to eq "Patient-Audit"
        expect(event[:details][:audited_changes][:team_id]).to eq([nil, 1])
        expect(event[:created_at]).to eq patient.audits.second.created_at
      end

      it "does not include audited changes that are not allowed" do
        patient.audits.create!(
          audited_changes: {
            given_name: %w[Alessia Alice]
          }
        )
        events = timeline.load_events(["audits"])
        expect(events.size).to eq 3
        expect(events.first[:event_type]).to eq "Patient-Audit"
        expect(events.first[:details]).to eq(
          { action: nil, auditable_id: patient.id }
        )
      end

      it "includes associated audits by default" do
        consent.audits << consent_audit
        events = timeline.load_events(["audits"])
        associated_event = events.find { |e| e[:id] == consent_audit.id }
        expect(associated_event).to be_present
        expect(associated_event[:event_type]).to eq "Consent-Audit"
      end

      it "excludes audits with only updated_from_pds_at changes" do
        patient.audits.create!(
          audited_changes: {
            updated_from_pds_at: [nil, Time.current]
          }
        )
        patient.audits.create!(audited_changes: { team_id: [nil, 1] })
        events = timeline.load_events(["audits"])
        expect(events.size).to eq 3 # create is the first audit, PatientSession-Audit is the second
        event = events.first
        expect(event[:details][:audited_changes]).not_to have_key(
          :updated_from_pds_at
        )
        expect(event[:details][:audited_changes][:team_id]).to eq([nil, 1])
      end
    end

    context "with show_pii: true" do
      let(:show_pii) { true }

      it "includes PII-based audited changes" do
        patient.audits.create!(
          audited_changes: {
            given_name: %w[Alessia Alice],
            organisation_id: [nil, 1]
          }
        )
        events = timeline.load_events(["audits"])
        expect(events.first[:details][:audited_changes]).to have_key(
          :given_name
        )
        expect(events.first[:details][:audited_changes]).to have_key(
          :organisation_id
        )
      end
    end

    context "with include_associated_audits: false" do
      let(:timeline) do
        described_class.new(
          patient,
          audit_config: {
            include_associated_audits: false
          }
        )
      end

      it "does not include associated audits" do
        consent.audits << consent_audit
        events = timeline.load_events(["audits"])
        associated_event = events.find { |e| e[:id] == consent_audit.id }
        expect(associated_event).to be_nil
      end

      it "still includes patient audits" do
        patient.audits.create!(audited_changes: { team_id: [nil, 1] })
        events = timeline.load_events(["audits"])
        expect(events.size).to eq 2
        expect(events.first[:event_type]).to eq "Patient-Audit"
      end
    end

    context "with include_filtered_audit_changes: true" do
      let(:timeline) do
        described_class.new(
          patient,
          audit_config: {
            include_filtered_audit_changes: true
          }
        )
      end

      it "includes filtered changes with [FILTERED] value" do
        patient.audits.create!(
          audited_changes: {
            given_name: %w[Alessia Alice]
          }
        )
        events = timeline.load_events(["audits"])
        expect(events.first[:details][:audited_changes][:given_name]).to eq(
          "[FILTERED]"
        )
      end
    end
  end

  describe "#additional_events" do
    let(:cohort_imports_with_patient) do
      create_list(:cohort_import, 2, team: session.team)
    end
    let(:cohort_imports_without_patient) do
      create_list(:cohort_import, 1, team: session.team)
    end

    before do
      class_import_additional.location_id = session.id
      create(:patient_location, patient:, location: session.location, session:)
      patient.class_imports = [class_import]
      patient.cohort_imports = cohort_imports_with_patient
      team.cohort_imports =
        cohort_imports_with_patient + cohort_imports_without_patient
    end

    context "with class imports" do
      it "returns a hash with class imports and cohort imports" do
        result = timeline.additional_events(patient)
        expect(result).to be_a(Hash)
        expect(result.keys).to eq(%i[class_imports cohort_imports])
      end

      it "returns class imports that the patient is not in, for sessions that the patient is in" do
        result = timeline.additional_events(patient)
        expect(result[:class_imports]).to be_a(Hash)
        expect(result[:class_imports].keys).to eq([session.location.id])
        expect(result[:class_imports][session.location.id]).to eq(
          [class_import_additional.id]
        )
      end
    end

    context "with cohort imports" do
      it "returns cohort imports that the patient is not in, for teams that the patient is in" do
        result = timeline.additional_events(patient)
        expect(result[:cohort_imports]).to eq(
          cohort_imports_without_patient.pluck(:id)
        )
      end
    end
  end

  describe "#patient_events" do
    let(:class_imports) { create_list(:class_import, 3, session:) }
    let(:cohort_imports) { create_list(:cohort_import, 3, team: session.team) }

    before do
      patient.class_imports = class_imports
      patient.cohort_imports = cohort_imports
      create(:patient_location, patient:, location: session.location, session:)
    end

    context "with class imports" do
      it "returns a hash with class imports, cohort imports, and sessions" do
        result = timeline.patient_events(patient)
        expect(result).to be_a(Hash)
        expect(result.keys).to eq(%i[class_imports cohort_imports sessions])
      end

      it "returns an array of class import IDs" do
        result = timeline.patient_events(patient)
        expect(result[:class_imports]).to eq(class_imports.pluck(:id))
      end
    end

    context "with cohort imports" do
      it "returns an array of cohort import IDs" do
        result = timeline.patient_events(patient)
        expect(result[:cohort_imports]).to eq(cohort_imports.pluck(:id))
      end
    end
  end

  describe "#load_grouped_events" do
    before do
      [consent, second_consent, third_consent, fourth_consent].each do |c|
        patient.consents << c
      end
      [
        vaccination_record,
        second_vaccination_record,
        third_vaccination_record,
        fourth_vaccination_record
      ].each { |vr| patient.vaccination_records << vr }
      create(:patient_location, patient:, location: session.location, session:)
      timeline.send(:load_events, %w[consents triages])
      timeline.send(:load_grouped_events, %w[consents triages])
    end

    it "groups events by date" do
      grouped_events = timeline.instance_variable_get(:@grouped_events)
      dates = grouped_events.keys
      expect(grouped_events).to be_a(Hash)
      expect(grouped_events.keys).to all(be_a(String))
      expect(grouped_events.values).to all(be_an(Array))
      expect(dates.uniq.size).to eq(dates.size)
    end

    it "orders events by date in descending order" do
      grouped_events = timeline.instance_variable_get(:@grouped_events)
      dates = grouped_events.keys
      expect(dates).to eq(
        ["1 April 2025", "1 March 2025", "1 February 2025", "1 January 2025"]
      )
    end
  end
end
