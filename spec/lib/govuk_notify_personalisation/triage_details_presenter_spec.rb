# frozen_string_literal: true

describe GovukNotifyPersonalisation::TriageDetailsPresenter do
  subject(:triage_details_presenter) { described_class.new(personalisation) }

  include_context "govuk notify personalisation context"

  context "delayed triage" do
    context "created on day of session" do
      let(:session) { create(:session, :today, location:, team:, programmes:) }

      before do
        create(
          :triage,
          :delay_vaccination,
          patient:,
          programme: programmes.first
        )
      end

      it do
        expect(triage_details_presenter).to have_attributes(
          delay_vaccination_review_context:
            "assessed John in the vaccination session"
        )
      end
    end

    context "created before session starts" do
      let(:session) { create(:session, :today, location:, team:, programmes:) }

      before do
        create(
          :triage,
          :delay_vaccination,
          patient:,
          created_at: Date.yesterday,
          programme: programmes.first
        )
      end

      it do
        expect(triage_details_presenter).to have_attributes(
          delay_vaccination_review_context:
            "reviewed the answers you gave to the health questions about John"
        )
      end
    end

    context "created after session starts" do
      let(:session) do
        create(:session, :yesterday, location:, team:, programmes:)
      end

      before do
        create(
          :triage,
          :delay_vaccination,
          patient:,
          programme: programmes.first
        )
      end

      it do
        expect(triage_details_presenter).to have_attributes(
          delay_vaccination_review_context:
            "reviewed the answers you gave to the health questions about John"
        )
      end
    end
  end
end
