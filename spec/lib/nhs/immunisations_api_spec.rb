# frozen_string_literal: true

describe NHS::ImmunisationsAPI do
  before do
    Flipper.enable(:imms_api_integration)
    Flipper.enable(:imms_api_sentry_warnings)
    Flipper.enable(:imms_api_sync_job, Programme.hpv)
  end

  let(:team) { create(:team, ods_code: "A9A5A") }
  let(:patient) do
    create(
      :patient,
      id: 31_337,
      team:,
      session:,
      address_postcode: "EC1A 1BB",
      nhs_number:,
      given_name: "Sarah",
      family_name: "Taylor",
      date_of_birth: Date.new(2011, 9, 9)
    )
  end
  let(:nhs_number) { "9449310475" }
  let(:programme) { Programme.hpv }
  let(:location) { create(:community_clinic, team:, ods_code: nil) }
  let(:vaccine) { programme.vaccines.find_by!(brand: "Gardasil") }
  let(:batch) do
    create(:batch, vaccine:, expiry: "2023-03-20", number: "X8U375AL")
  end
  let(:session) { create(:session, team:, programmes: [programme], location:) }
  let(:user) do
    create(:user, team:, family_name: "Nightingale", given_name: "Florence")
  end
  let(:nhs_immunisations_api_synced_at) { nil }
  let(:nhs_immunisations_api_etag) { nil }
  let(:nhs_immunisations_api_id) { nil }
  let(:nhs_immunisations_api_primary_source) { nil }
  let(:nhs_immunisations_api_sync_pending_at) { nil }
  let(:vaccination_record) do
    create(
      :vaccination_record,
      uuid: "11112222-3333-4444-5555-666677778888",
      team:,
      patient:,
      programme:,
      location:,
      location_name: nil,
      vaccine:,
      batch:,
      session:,
      performed_by_user: user,
      performed_at: Time.zone.parse("2021-02-07T13:28:17.271+00:00"),
      created_at: Time.zone.parse("2021-02-07T13:28:17.271+00:00"),
      nhs_immunisations_api_synced_at:,
      nhs_immunisations_api_id:,
      nhs_immunisations_api_primary_source:,
      nhs_immunisations_api_etag:,
      nhs_immunisations_api_sync_pending_at:,
      notify_parents:
    )
  end
  let(:notify_parents) { true }

  shared_examples "an imms_api_integration feature flag check" do
    context "the imms_api_integration feature flag is disabled" do
      before { Flipper.disable(:imms_api_integration) }

      it "does not make a request to the NHS API" do
        perform_request

        expect(request_stub).not_to have_been_made
      end
    end
  end

  shared_examples "unexpected response status" do |unexpected_status, action|
    context "unexpected response status" do
      let(:status) { unexpected_status }
      let(:response) { "" }

      it "raises an error saying the response is unexpected" do
        if action == "searching"
          expect { perform_request }.to raise_error(
            Regexp.new(
              "Error searching for vaccination records for patient #{patient.id}" \
                " in Immunisations API: unexpected response status"
            )
          )
        elsif action == "reading_by_id"
          expect { perform_request }.to raise_error(
            Regexp.new(
              "Error reading vaccination record from Immunisations API by NHS" \
                " Immunisations API ID ffff1111-eeee-2222-dddd-3333eeee4444: unexpected" \
                " response status"
            )
          )
        else
          expect { perform_request }.to raise_error(
            Regexp.new(
              "Error #{action} vaccination record #{vaccination_record.id}" \
                " (to|from) Immunisations API: unexpected response status"
            )
          )
        end
      end
    end
  end

  shared_examples "client error (4XX) handling" do |action|
    context "4XX error" do
      let(:status) { 404 }
      let(:diagnostics) { "Invalid patient ID" }

      it "raises an error with the diagnostic message" do
        if action == "searching"
          expect { perform_request }.to raise_error(
            Regexp.new(
              "Error #{action} for vaccination records for patient #{patient.id}" \
                " in Immunisations API: Invalid patient ID"
            )
          )
        elsif action == "reading_by_id"
          expect { perform_request }.to raise_error(
            Regexp.new(
              "Error reading vaccination record from Immunisations API by" \
                " NHS Immunisations API ID ffff1111-eeee-2222-dddd-3333eeee4444: Invalid patient ID"
            )
          )
        else
          expect { perform_request }.to raise_error(
            Regexp.new(
              "Error #{action} vaccination record #{vaccination_record.id}" \
                " (to|from) Immunisations API: Invalid patient ID"
            )
          )
        end
      end
    end
  end

  shared_examples "generic error handling" do
    context "generic error" do
      let(:status) { 500 }

      it "raises an error with the diagnostic message" do
        expect { perform_request }.to raise_error(Faraday::Error)
      end
    end
  end

  shared_examples "deletes the immunisation record if previously recorded" do
    context "the patient has no NHS number" do
      before { patient.update(nhs_number: nil) }

      context "the vaccination record has not been synced before" do
        it { should be_nil }
      end

      context "the vaccination record has been synced before" do
        let(:nhs_immunisations_api_id) { Random.uuid }
        let(:nhs_immunisations_api_primary_source) { true }
        let(:nhs_immunisations_api_synced_at) { 2.seconds.ago }
        let(:nhs_immunisations_api_sync_pending_at) { 1.second.ago }
        let(:nhs_immunisations_api_etag) { "1" }

        it { should eq :delete }
      end
    end
  end

  describe "sync_immunisation" do
    subject(:perform_now) do
      described_class.sync_immunisation(vaccination_record)
    end

    before do
      allow(described_class).to receive(:next_sync_action).and_return(
        next_sync_action
      )

      allow(described_class).to receive(:create_immunisation)
      allow(described_class).to receive(:update_immunisation)
      allow(described_class).to receive(:delete_immunisation)

      perform_now
    end

    context "the next sync action is create" do
      let(:next_sync_action) { :create }

      it "calls update_immunisation" do
        expect(described_class).to have_received(:create_immunisation)
      end
    end

    context "the next sync action is update" do
      let(:next_sync_action) { :update }

      it "calls update_immunisation" do
        expect(described_class).to have_received(:update_immunisation)
      end
    end

    context "the next sync action is delete" do
      let(:next_sync_action) { :delete }

      it "calls update_immunisation" do
        expect(described_class).to have_received(:delete_immunisation)
      end
    end

    context "the next sync action is unknown" do
      let(:next_sync_action) { :nil }

      it "does not do any further action" do
        expect(described_class).not_to have_received(:create_immunisation)
        expect(described_class).not_to have_received(:update_immunisation)
        expect(described_class).not_to have_received(:delete_immunisation)
      end
    end
  end

  describe "create_immunisation" do
    subject(:perform_request) do
      described_class.create_immunisation(vaccination_record)
    end

    let!(:request_stub) do
      stub_request(
        :post,
        "https://sandbox.api.service.nhs.uk/immunisation-fhir-api/FHIR/R4/Immunization"
      ).to_return(status:, body:, headers:)
    end

    let(:status) { 201 }
    let(:body) { "" }
    let(:headers) do
      {
        location:
          "https://sandbox.api.service.nhs.uk/immunisation-fhir-api/Immunization/ffff1111-eeee-2222-dddd-3333eeee4444"
      }
    end

    it "sends the correct JSON payload" do
      expected_body = file_fixture("fhir/immunisation_create.json").read.chomp

      request_stub.with do |request|
        expect(request.headers).to include(
          {
            "Accept" => "application/fhir+json",
            "Content-Type" => "application/fhir+json"
          }
        )
        expect(request.body).to eq expected_body
        true
      end

      perform_request

      expect(request_stub).to have_been_made
    end

    it "stores the id from the response" do
      perform_request

      expect(
        vaccination_record.nhs_immunisations_api_id
      ).to eq "ffff1111-eeee-2222-dddd-3333eeee4444"
    end

    it "sets the nhs_immunisations_api_synced_at" do
      freeze_time do
        perform_request

        expect(
          vaccination_record.nhs_immunisations_api_synced_at
        ).to eq Time.current
      end
    end

    it "initialises the etag to 1" do
      perform_request

      expect(vaccination_record.nhs_immunisations_api_etag).to eq "1"
    end

    it "does not change the updated_at timestamp" do
      original_updated_at = vaccination_record.updated_at

      # Small delay to ensure time difference if updated_at were to change
      travel 1.second

      perform_request

      expect(vaccination_record.reload.updated_at).to eq original_updated_at
    end

    context "an error is returned by the api" do
      let(:code) { nil }
      let(:diagnostics) { nil }
      let(:headers) { {} }
      let(:body) do
        {
          resourceType: "OperationOutcome",
          id: "bc2c3c82-4392-4314-9d6b-a7345f82d923",
          meta: {
            profile: [
              "https://simplifier.net/guide/UKCoreDevelopment2/ProfileUKCore-OperationOutcome"
            ]
          },
          issue: [
            {
              severity: "error",
              code: "invalid",
              details: {
                coding: [
                  {
                    system: "https://fhir.nhs.uk/Codesystem/http-error-codes",
                    code:
                  }
                ]
              },
              diagnostics:
            }
          ]
        }.to_json
      end

      include_examples "unexpected response status", 200, "recording"
      include_examples "client error (4XX) handling", "recording"
      include_examples "generic error handling"
    end

    include_examples "an imms_api_integration feature flag check"
  end

  describe "read immunisation_by_nhs_immunisations_api_id" do
    subject(:perform_request) do
      described_class.read_immunisation_by_nhs_immunisations_api_id(
        "ffff1111-eeee-2222-dddd-3333eeee4444"
      )
    end

    let(:status) { 200 }
    let(:body) { file_fixture("fhir/flu/fhir_record_full.json").read }
    let(:headers) { { "content-type" => "application/fhir+json" } }

    let!(:request_stub) do
      stub_request(
        :get,
        "https://sandbox.api.service.nhs.uk/immunisation-fhir-api/FHIR/R4/Immunization/ffff1111-eeee-2222-dddd-3333eeee4444"
      ).to_return(status:, body:, headers:)
    end

    include_examples "an imms_api_integration feature flag check"

    it "sends the correct request" do
      request_stub.with do |request|
        expect(request.headers).to include(
          { "Accept" => "application/fhir+json" }
        )
      end

      perform_request

      expect(request_stub).to have_been_made
    end

    it "returns the FHIR record" do
      expect(perform_request).to be_a FHIR::Immunization
    end

    context "an error is returned by the api" do
      let(:code) { nil }
      let(:diagnostics) { nil }

      let(:body) do
        {
          resourceType: "OperationOutcome",
          id: "bc2c3c82-4392-4314-9d6b-a7345f82d923",
          meta: {
            profile: [
              "https://simplifier.net/guide/UKCoreDevelopment2/ProfileUKCore-OperationOutcome"
            ]
          },
          issue: [
            {
              severity: "error",
              code: "invalid",
              details: {
                coding: [
                  {
                    system: "https://fhir.nhs.uk/Codesystem/http-error-codes",
                    code:
                  }
                ]
              },
              diagnostics:
            }
          ]
        }.to_json
      end

      include_examples "unexpected response status", 201, "reading_by_id"
      include_examples "client error (4XX) handling", "reading_by_id"
      include_examples "generic error handling"
    end
  end

  describe "read immunisation" do
    subject(:perform_request) do
      described_class.read_immunisation(vaccination_record)
    end

    let(:status) { 200 }
    let(:body) { file_fixture("fhir/flu/fhir_record_full.json").read }
    let(:headers) { { "content-type" => "application/fhir+json" } }

    let!(:request_stub) do
      stub_request(
        :get,
        "https://sandbox.api.service.nhs.uk/immunisation-fhir-api/FHIR/R4/Immunization/ffff1111-eeee-2222-dddd-3333eeee4444"
      ).to_return(status:, body:, headers:)
    end

    before do
      vaccination_record.update(
        nhs_immunisations_api_id: "ffff1111-eeee-2222-dddd-3333eeee4444"
      )
    end

    include_examples "an imms_api_integration feature flag check"

    it "sends the correct request" do
      request_stub.with do |request|
        expect(request.headers).to include(
          { "Accept" => "application/fhir+json" }
        )
      end

      perform_request

      expect(request_stub).to have_been_made
    end

    it "returns the FHIR record" do
      expect(perform_request).to be_a FHIR::Immunization
    end
  end

  describe "update immunisations" do
    subject(:perform_request) do
      described_class.update_immunisation(vaccination_record)
    end

    let(:status) { 200 }
    let(:body) { "" }
    let!(:request_stub) do
      stub_request(
        :put,
        "https://sandbox.api.service.nhs.uk/immunisation-fhir-api/FHIR/R4/Immunization/ffff1111-eeee-2222-dddd-3333eeee4444"
      ).to_return(status:, body:)
    end

    before do
      vaccination_record.update(
        nhs_immunisations_api_id: "ffff1111-eeee-2222-dddd-3333eeee4444",
        nhs_immunisations_api_primary_source: true,
        nhs_immunisations_api_synced_at: Date.yesterday,
        nhs_immunisations_api_etag: 1
      )
    end

    it "sends the correct JSON payload" do
      expected_body = file_fixture("fhir/immunisation_update.json").read.chomp

      request_stub.with do |request|
        expect(request.headers).to include(
          {
            "Accept" => "application/fhir+json",
            "Content-Type" => "application/fhir+json",
            "E-Tag" => "1"
          }
        )
        expect(request.body).to eq expected_body
        true
      end

      perform_request

      expect(request_stub).to have_been_made
    end

    include_examples "an imms_api_integration feature flag check"

    it "sets the nhs_immunisations_api_synced_at" do
      freeze_time do
        perform_request

        expect(
          vaccination_record.nhs_immunisations_api_synced_at
        ).to eq Time.current
      end
    end

    it "does not change the updated_at timestamp" do
      original_updated_at = vaccination_record.updated_at

      # Small delay to ensure time difference if updated_at were to change
      travel 1.second

      perform_request

      expect(vaccination_record.reload.updated_at).to eq original_updated_at
    end

    it "increments the etag" do
      perform_request

      expect(vaccination_record.nhs_immunisations_api_etag).to eq "2"
    end

    context "an error is returned by the api" do
      let(:code) { nil }
      let(:diagnostics) { nil }

      let(:body) do
        {
          resourceType: "OperationOutcome",
          id: "bc2c3c82-4392-4314-9d6b-a7345f82d923",
          meta: {
            profile: [
              "https://simplifier.net/guide/UKCoreDevelopment2/ProfileUKCore-OperationOutcome"
            ]
          },
          issue: [
            {
              severity: "error",
              code: "invalid",
              details: {
                coding: [
                  {
                    system: "https://fhir.nhs.uk/Codesystem/http-error-codes",
                    code:
                  }
                ]
              },
              diagnostics:
            }
          ]
        }.to_json
      end

      include_examples "unexpected response status", 201, "updating"
      include_examples "client error (4XX) handling", "updating"
      include_examples "generic error handling"
    end
  end

  describe "delete immunisations" do
    subject(:perform_request) do
      described_class.delete_immunisation(vaccination_record)
    end

    let(:status) { 204 }
    let(:body) { "" }
    let!(:request_stub) do
      stub_request(
        :delete,
        "https://sandbox.api.service.nhs.uk/immunisation-fhir-api/FHIR/R4/Immunization/ffff1111-eeee-2222-dddd-3333eeee4444"
      ).to_return(status:, body:)
    end

    before do
      vaccination_record.update(
        nhs_immunisations_api_id: "ffff1111-eeee-2222-dddd-3333eeee4444",
        nhs_immunisations_api_primary_source: true,
        nhs_immunisations_api_synced_at: Date.yesterday,
        nhs_immunisations_api_etag: 1
      )
    end

    it "sends the correct request" do
      request_stub.with do |request|
        expect(request.headers).to include(
          { "Accept" => "application/fhir+json", "E-Tag" => "1" }
        )
      end

      perform_request

      expect(request_stub).to have_been_made
    end

    include_examples "an imms_api_integration feature flag check"

    it "sets the nhs_immunisations_api_synced_at" do
      freeze_time do
        perform_request

        expect(
          vaccination_record.nhs_immunisations_api_synced_at
        ).to eq Time.current
      end
    end

    it "sets the nhs_immunisations_api_id to nil" do
      freeze_time do
        perform_request

        expect(vaccination_record.nhs_immunisations_api_id).to be_nil
      end
    end

    it "does not change the updated_at timestamp" do
      original_updated_at = vaccination_record.updated_at

      # Small delay to ensure time difference if updated_at were to change
      travel 1.second

      perform_request

      expect(vaccination_record.reload.updated_at).to eq original_updated_at
    end

    context "an error is returned by the api" do
      let(:code) { nil }
      let(:diagnostics) { nil }

      let(:body) do
        {
          resourceType: "OperationOutcome",
          id: "bc2c3c82-4392-4314-9d6b-a7345f82d923",
          meta: {
            profile: [
              "https://simplifier.net/guide/UKCoreDevelopment2/ProfileUKCore-OperationOutcome"
            ]
          },
          issue: [
            {
              severity: "error",
              code: "invalid",
              details: {
                coding: [
                  {
                    system: "https://fhir.nhs.uk/Codesystem/http-error-codes",
                    code:
                  }
                ]
              },
              diagnostics:
            }
          ]
        }.to_json
      end

      include_examples "unexpected response status", 200, "deleting"
      include_examples "client error (4XX) handling", "deleting"
      include_examples "generic error handling"
    end
  end

  describe "next_sync_action" do
    subject(:next_sync_action) do
      described_class.send(:next_sync_action, vaccination_record)
    end

    let(:nhs_immunisations_api_sync_pending_at) { 1.second.ago }

    context "the vaccination record has not been synced" do
      it { should eq :create }
    end

    context "the vaccination record has been synced before" do
      let(:nhs_immunisations_api_synced_at) { 2.seconds.ago }
      let(:nhs_immunisations_api_id) { Random.uuid }
      let(:nhs_immunisations_api_primary_source) { true }
      let(:nhs_immunisations_api_sync_pending_at) { 1.second.ago }

      it { should eq :update }
    end

    context "the sync pending is nil" do
      before do
        # This is necessary because of the `before_save :touch_nhs_immunisations_api_sync_pending_at` hook on
        # VaccinationRecord
        vaccination_record.update(nhs_immunisations_api_sync_pending_at: nil)
      end

      it "raises an error" do
        expect { next_sync_action }.to raise_error(
          "Cannot sync vaccination record #{vaccination_record.id}:" \
            " nhs_immunisations_api_sync_pending_at is nil"
        )
      end
    end

    context "the vaccination record is already in-sync" do
      before do
        vaccination_record.update_columns(
          nhs_immunisations_api_synced_at: 1.second.ago,
          nhs_immunisations_api_id: Random.uuid,
          nhs_immunisations_api_primary_source: true,
          nhs_immunisations_api_sync_pending_at: 2.seconds.ago
        )
      end

      it { should be_nil }
    end

    context "the vaccination record has been discarded" do
      before { vaccination_record.discard! }

      include_examples "deletes the immunisation record if previously recorded"
    end

    context "the vaccination record is being discarded again" do
      before do
        vaccination_record.update!(
          discarded_at: 3.seconds.ago,
          nhs_immunisations_api_synced_at: 2.seconds.ago,
          nhs_immunisations_api_sync_pending_at: 1.second.ago,
          nhs_immunisations_api_id: Random.uuid,
          nhs_immunisations_api_primary_source: true
        )
      end

      it { should be_nil }
    end

    context "the patient has no NHS number" do
      before { patient.update(nhs_number: nil) }

      it { should eq :create }
    end

    VaccinationRecord.defined_enums["outcome"].each_key do |outcome|
      next if outcome == "administered"

      context "the vaccination record outcome is #{outcome}" do
        let(:vaccination_record) do
          create(
            :vaccination_record,
            outcome:,
            patient:,
            nhs_immunisations_api_synced_at:,
            nhs_immunisations_api_id:,
            nhs_immunisations_api_primary_source:,
            nhs_immunisations_api_etag:,
            nhs_immunisations_api_sync_pending_at:
          )
        end

        include_examples "deletes the immunisation record if previously recorded"
      end
    end
  end

  describe "search_immunisations" do
    subject(:perform_request) do
      described_class.search_immunisations(
        patient,
        programmes:,
        date_from:,
        date_to:
      )
    end

    shared_examples "continues the request and returns the bundle anyway" do |num_records, num_entries|
      it "continues the request and returns the bundle anyway" do
        expect(perform_request).to be_a FHIR::Bundle
        expect(perform_request.total).to be num_records
        expect(perform_request.entry.size).to be num_entries
        expect(
          perform_request.entry.first(num_records).map(&:resource)
        ).to all be_a FHIR::Immunization
      end
    end

    let(:nhs_number) { "9449308357" }
    let(:programmes) do
      [
        Programme.hpv,
        Programme.flu,
        Programme.menacwy,
        Programme.td_ipv,
        Programme.mmr
      ]
    end
    let(:date_from) { Time.new(2025, 8, 1, 12, 30, 37, "+01:00") }
    let(:date_to) { Time.new(2025, 10, 1, 10, 35, 32, "+01:00") }

    let!(:request_stub) do
      stub_request(
        :get,
        "https://sandbox.api.service.nhs.uk/immunisation-fhir-api/FHIR/R4/Immunization"
      ).with(query: expected_query).to_return(status:, body:, headers:)
    end

    let(:expected_query) do
      {
        "patient.identifier" =>
          "https://fhir.nhs.uk/Id/nhs-number|#{patient.nhs_number}",
        "-immunization.target" => "3IN1,FLU,HPV,MENACWY,MMR,MMRV",
        "-date.from" => "2025-08-01",
        "-date.to" => "2025-10-01"
      }
    end

    let(:status) { 200 }
    let(:body) { file_fixture("fhir/search_response_full_bundle.json").read }
    let(:headers) { { "content-type" => "application/fhir+json" } }
    let(:diagnostics) { nil }

    it "sends the correct request" do
      request_stub.with do |request|
        expect(request.headers).to include(
          {
            "Accept" => "application/fhir+json",
            "Content-Type" => "application/fhir+json"
          }
        )
        expect(request.body).to be_blank
        true
      end

      perform_request

      expect(request_stub).to have_been_made
    end

    context "with non-matching `Bundle.link` parameters" do
      let(:date_to) { nil }

      let(:expected_query) do
        {
          "patient.identifier" =>
            "https://fhir.nhs.uk/Id/nhs-number|#{patient.nhs_number}",
          "-immunization.target" => "3IN1,FLU,HPV,MENACWY,MMR,MMRV",
          "-date.from" => "2025-08-01"
        }
      end

      it "raises a warning, and sends to Sentry" do
        expect(Rails.logger).to receive(:warn)
        expect(Sentry).to receive(:capture_exception).with(
          NHS::ImmunisationsAPI::BundleLinkParamsMismatch
        )

        perform_request
      end

      context "when imms_api_sentry_warnings feature flag is disabled" do
        before { Flipper.disable(:imms_api_sentry_warnings) }
        after { Flipper.enable(:imms_api_sentry_warnings) }

        it "does not send the warning to Sentry, but still logs" do
          expect(Rails.logger).to receive(:warn)
          expect(Sentry).not_to receive(:capture_exception)

          perform_request
        end
      end

      include_examples "continues the request and returns the bundle anyway",
                       2,
                       3
    end

    context "with an operation outcome in bundle" do
      context "when the severity is `error`" do
        let(:body) do
          file_fixture("fhir/search_response_operation_outcome_error.json").read
        end

        it "raises an error" do
          expect { perform_request }.to raise_error(
            NHS::ImmunisationsAPI::OperationOutcomeInBundle
          )
        end
      end

      context "when the severity is `fatal`" do
        let(:body) do
          file_fixture("fhir/search_response_operation_outcome_fatal.json").read
        end

        it "raises an error" do
          expect { perform_request }.to raise_error(
            NHS::ImmunisationsAPI::OperationOutcomeInBundle
          )
        end
      end

      context "when the severity is `warning`" do
        let(:body) do
          file_fixture(
            "fhir/search_response_operation_outcome_warning.json"
          ).read
        end

        it "doesn't raise an error" do
          expect { perform_request }.not_to raise_error
        end

        it "raises a warning, and sends to Sentry" do
          expect(Rails.logger).to receive(:warn)
          expect(Sentry).to receive(:capture_exception).with(
            NHS::ImmunisationsAPI::OperationOutcomeInBundle
          )

          perform_request
        end

        include_examples "continues the request and returns the bundle anyway",
                         1,
                         3

        context "when imms_api_sentry_warnings feature flag is disabled" do
          before { Flipper.disable(:imms_api_sentry_warnings) }
          after { Flipper.enable(:imms_api_sentry_warnings) }

          it "does not send the warning to Sentry, but still logs" do
            expect(Rails.logger).to receive(:warn)
            expect(Sentry).not_to receive(:capture_exception)

            perform_request
          end
        end
      end

      context "when the severity is `success`" do
        let(:body) do
          file_fixture(
            "fhir/search_response_operation_outcome_success.json"
          ).read
        end

        it "doesn't raise an error" do
          expect { perform_request }.not_to raise_error
        end

        include_examples "continues the request and returns the bundle anyway",
                         1,
                         3
      end
    end

    describe "handling `-immunization.target` in `Bundle.link`" do
      context "with `immunization+target` (incorrect, and unexpected)" do
        let(:body) do
          file_fixture("fhir/search_response_bad_immunization_target.json").read
        end

        it "doesn't raise an error" do
          expect { perform_request }.not_to raise_error
        end

        it "raises a warning, and sends to Sentry" do
          expect(Rails.logger).to receive(:warn)
          expect(Sentry).to receive(:capture_exception).with(
            NHS::ImmunisationsAPI::BundleLinkParamsMismatch
          )

          perform_request
        end

        include_examples "continues the request and returns the bundle anyway",
                         2,
                         3
      end

      context "with both `immunization.target` and `-immunization.target` (as is currently in production)" do
        let(:body) do
          file_fixture(
            "fhir/search_response_immunization_target_both.json"
          ).read
        end

        it "doesn't raise an error" do
          expect { perform_request }.not_to raise_error
        end

        it "doesn't raise a warning, and doesn't send to Sentry" do
          expect(Rails.logger).not_to receive(:warn)
          expect(Sentry).not_to receive(:capture_exception).with(
            NHS::ImmunisationsAPI::BundleLinkParamsMismatch
          )

          perform_request
        end

        include_examples "continues the request and returns the bundle anyway",
                         2,
                         3
      end

      context "with `-immunization.target` (correct)" do
        let(:body) do
          file_fixture(
            "fhir/search_response_immunization_target_good.json"
          ).read
        end

        it "doesn't raise an error" do
          expect { perform_request }.not_to raise_error
        end

        it "doesn't raise a warning, and doesn't send to Sentry" do
          expect(Rails.logger).not_to receive(:warn)
          expect(Sentry).not_to receive(:capture_exception).with(
            NHS::ImmunisationsAPI::BundleLinkParamsMismatch
          )

          perform_request
        end

        include_examples "continues the request and returns the bundle anyway",
                         2,
                         3
      end
    end

    include_examples "generic error handling"
    include_examples "unexpected response status", 250, "searching"

    include_examples "an imms_api_integration feature flag check"

    context "for MMRV" do
      let(:date_from) { nil }
      let(:date_to) { nil }

      let(:expected_query) do
        {
          "patient.identifier" =>
            "https://fhir.nhs.uk/Id/nhs-number|#{patient.nhs_number}",
          "-immunization.target" => "3IN1,FLU,HPV,MENACWY,MMR,MMRV"
        }
      end

      let(:body) do
        file_fixture("fhir/search_response_1_result_mmrv.json").read
      end

      it_behaves_like "continues the request and returns the bundle anyway",
                      1,
                      2
    end

    context "with patients uploaded as part of national reporting" do
      before do
        create(
          :vaccination_record,
          :sourced_from_national_reporting,
          team:,
          patient:
        )
      end

      let(:team) { create(:team, :national_reporting, ods_code: "A9A5A") }

      it "does not perform a search" do
        perform_request

        expect(request_stub).not_to have_been_made
      end
    end

    context "with patients without a team" do
      let(:session) { nil }

      it "does not perform a search" do
        perform_request

        expect(request_stub).not_to have_been_made
      end
    end
  end
end
