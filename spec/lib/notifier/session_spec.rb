# frozen_string_literal: true

describe Notifier::Session do
  subject(:notifier) { described_class.new(session) }

  let(:programme) { Programme.flu }
  let(:team) { create(:team, programmes: [programme]) }
  let(:location) { create(:generic_clinic, team:, programmes: [programme]) }
  let(:session) do
    create(:session, :scheduled, team:, location:, programmes: [programme])
  end
  let(:sent_by) { create(:user) }

  describe "#send_cancellation" do
    subject(:send_cancellation) { notifier.send_cancellation(sent_by:) }

    let(:consenting_parent) { create(:parent) }
    let(:non_consenting_parent) { create(:parent) }

    let(:patient) do
      create(
        :patient,
        session:,
        parents: [consenting_parent, non_consenting_parent]
      )
    end

    context "when a parent gave consent" do
      before do
        create(
          :consent,
          :given,
          patient:,
          parent: consenting_parent,
          programme:,
          team:
        )
      end

      it "sends an email only to the parent who gave consent" do
        expect { send_cancellation }.to have_delivered_email(
          :session_clinic_cancelled
        ).with(parent: consenting_parent, patient:, session:, sent_by:)
      end

      it "does not send an email to the non-consenting parent" do
        expect { send_cancellation }.not_to have_delivered_email.with(
          parent: non_consenting_parent,
          patient:,
          session:,
          sent_by:
        )
      end
    end

    context "when consent was given via self consent" do
      before { create(:consent, :self_consent, :given, patient:, programme:) }

      it "sends an email to all contactable parents" do
        expect { send_cancellation }.to have_delivered_email(
          :session_clinic_cancelled
        ).with(
          parent: consenting_parent,
          patient:,
          session:,
          sent_by:
        ).and have_delivered_email(:session_clinic_cancelled).with(
                parent: non_consenting_parent,
                patient:,
                session:,
                sent_by:
              )
      end
    end
  end
end
