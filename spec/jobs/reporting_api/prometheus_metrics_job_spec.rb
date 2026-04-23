# frozen_string_literal: true

require "prometheus_exporter/client"

describe ReportingAPI::PrometheusMetricsJob do
  describe "#perform" do
    subject(:perform) { described_class.new.perform }

    let(:client) { instance_double(PrometheusExporter::Client) }
    let(:gauge) { instance_double(PrometheusExporter::Client::RemoteMetric) }

    before do
      allow(PrometheusExporter::Client).to receive(:default).and_return(client)
      allow(client).to receive(:register).with(
        :gauge,
        anything,
        anything
      ).and_return(gauge)
      allow(gauge).to receive(:observe)
    end

    context "when EXPORT_REPORTING_METRICS is not set" do
      it "returns without querying or sending metrics" do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with("EXPORT_REPORTING_METRICS").and_return(
          nil
        )
        expect(ReportingAPI::Total).not_to receive(:refresh!)

        perform

        expect(gauge).not_to have_received(:observe)
      end
    end

    context "when EXPORT_REPORTING_METRICS is not true" do
      it "returns without querying or sending metrics" do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with("EXPORT_REPORTING_METRICS").and_return(
          "false"
        )
        expect(ReportingAPI::Total).not_to receive(:refresh!)

        perform

        expect(gauge).not_to have_received(:observe)
      end
    end

    context "when Flipper :reporting_api is disabled" do
      before do
        Flipper.disable(:reporting_api)
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with("EXPORT_REPORTING_METRICS").and_return(
          "true"
        )
      end

      it "returns without querying or sending metrics" do
        expect(ReportingAPI::Total).not_to receive(:refresh!)

        perform

        expect(gauge).not_to have_received(:observe)
      end
    end

    context "when PrometheusExporter::Client.default is nil" do
      before do
        Flipper.enable(:reporting_api)
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with("EXPORT_REPORTING_METRICS").and_return(
          "true"
        )
        allow(PrometheusExporter::Client).to receive(:default).and_return(nil)
      end

      it "returns without querying" do
        scope = class_double(ReportingAPI::Total)
        allow(ReportingAPI::Total).to receive(:not_archived).and_return(scope)
        allow(scope).to receive_messages(group: scope, select: scope)
        expect(ReportingAPI::Total).not_to receive(:refresh!)

        perform

        expect(scope).not_to have_received(:select)
      end
    end

    context "when EXPORT_REPORTING_METRICS is true and reporting_api is enabled and client is present" do
      before do
        Flipper.enable(:reporting_api)
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with("EXPORT_REPORTING_METRICS").and_return(
          "true"
        )
      end

      it "queries grouped totals and observes gauges for each row" do
        row =
          instance_double(
            ReportingAPI::Total,
            team_id: 1,
            programme_type: "flu",
            cohort: 100,
            vaccinated: 80,
            not_vaccinated: 20,
            consent_given: 85,
            no_consent: 15,
            consent_no_response: 5,
            consent_refused: 8,
            consent_conflicts: 2
          )
        # rubocop:disable RSpec/VerifiedDoubles
        # There does not exist an object in our codebase that represents correctly the type of object returned by
        # `group(...).select(...).with_aggregate_metrics`, so we cannot use a verified double here.
        scope = double("relation")
        # rubocop:enable RSpec/VerifiedDoubles

        allow(ReportingAPI::Total).to receive(:not_archived).and_return(scope)

        allow(scope).to receive_messages(
          group: scope,
          select: scope,
          with_aggregate_metrics: scope
        )
        allow(scope).to receive(:each).and_yield(row)

        perform

        expect(scope).to have_received(:group).with(:team_id, :programme_type)
        expect(scope).to have_received(:with_aggregate_metrics)
        expect(gauge).to have_received(:observe).exactly(8).times
        expect(gauge).to have_received(:observe).with(
          100,
          team_id: "1",
          programme_type: "flu"
        )
        expect(gauge).to have_received(:observe).with(
          80,
          team_id: "1",
          programme_type: "flu"
        )
      end
    end
  end
end
