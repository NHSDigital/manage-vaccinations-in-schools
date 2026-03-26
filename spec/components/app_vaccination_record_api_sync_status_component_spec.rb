# frozen_string_literal: true

describe AppVaccinationRecordAPISyncStatusComponent do
  let(:vaccination_record) do
    build(:vaccination_record, outcome:, programme:, session:)
  end
  let(:outcome) { "administered" }
  let(:programme) { Programme.flu }
  let(:session) { create(:session, programmes: [programme]) }

  let(:component) { described_class.new(vaccination_record) }
  let(:rendered) { render_inline(component) }

  before do
    Flipper.disable(:imms_api_sync_job)
    Flipper.enable(:imms_api_sync_job, programme)
  end

  describe "#call" do
    subject(:formatted_status) { rendered.to_html }

    context "when sync_status is :not_synced" do
      context "when vaccination was not administered" do
        before do
          allow(vaccination_record).to receive_messages(
            sync_status: :not_synced,
            administered?: false
          )
        end

        it do
          expect(formatted_status).to include(
            "Records are not synced if the vaccination was not given"
          )
        end
      end

      context "when vaccination programme is not currently sent to the API" do
        before do
          allow(vaccination_record).to receive(:sync_status).and_return(
            :not_synced
          )

          Flipper.disable(:imms_api_sync_job, programme)
        end

        it do
          expect(formatted_status).to include(
            "Records are currently not synced for this programme"
          )
        end
      end

      context "when record was created before the API integration was enabled" do
        before do
          allow(vaccination_record).to receive_messages(
            sync_status: :not_synced,
            created_before_api_integration?: true
          )
        end

        let(:programme) { Programme.td_ipv }

        it do
          expect(formatted_status).to include(
            "Td/IPV vaccinations recorded before 2 March 2026 are not synced with GP practices and NHS England"
          )
        end
      end

      context "when child requested that parents aren't notified" do
        before do
          allow(vaccination_record).to receive_messages(
            sync_status: :not_synced
          )
          vaccination_record.notify_parents = false
        end

        it do
          expect(formatted_status).to include(
            "The child gave consent under Gillick competence and does not want their parents to be notified. " \
              "You must let the child’s GP know they were vaccinated."
          )
        end
      end

      context "when vaccination has notify_parents false, but the programme is not sent to the API anyway" do
        before do
          allow(vaccination_record).to receive_messages(
            sync_status: :not_synced,
            notify_parents: false
          )

          Flipper.disable(:imms_api_sync_job, programme)
        end

        it do
          expect(formatted_status).to include(
            "Records are currently not synced for this programme"
          )
        end
      end
    end

    context "when sync_status is :failed" do
      before do
        allow(vaccination_record).to receive(:sync_status).and_return(:failed)
      end

      it do
        expect(formatted_status).to include(
          "The Mavis team is aware of the issue and is working to resolve it"
        )
      end
    end

    context "when sync_status is :synced" do
      before do
        allow(vaccination_record).to receive(:sync_status).and_return(:synced)
      end

      it { should include("Last synced:") }
    end

    context "when sync_status is :pending" do
      before do
        allow(vaccination_record).to receive(:sync_status).and_return(:pending)
      end

      it { should include("Last synced:") }
    end
  end
end
