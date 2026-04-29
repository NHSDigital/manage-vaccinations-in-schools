# frozen_string_literal: true

describe Notifier::VaccinationRecord do
  subject(:notifier) { described_class.new(vaccination_record) }

  before do
    vaccination_record.strict_loading!(false)
    vaccination_record.patient.strict_loading!(false)
  end

  let(:sent_by) { create(:user) }

  describe "#send_confirmation" do
    subject(:send_confirmation) { notifier.send_confirmation(sent_by:) }

    let(:programme) { Programme.hpv }
    let(:session) { create(:session, programmes: [programme]) }
    let(:parent) { create(:parent) }
    let(:patient) { create(:patient, parents: [parent], session:) }
    let(:vaccination_record) do
      create(:vaccination_record, programme:, patient:, session:)
    end

    context "when the vaccination has taken place" do
      before { create(:consent, :given, patient:, programme:) }

      it "sends an email" do
        expect { send_confirmation }.to deliver_email(
          :vaccination_administered
        ).with(
          parent_id: parent.id,
          vaccination_record_id: vaccination_record.id,
          sent_by_user_id: sent_by.id
        )
      end

      it "sends a text message" do
        expect { send_confirmation }.to deliver_sms(
          :vaccination_administered
        ).with(
          parent_id: parent.id,
          vaccination_record_id: vaccination_record.id,
          sent_by_user_id: sent_by.id
        )
      end
    end

    context "when the vaccination hasn't taken place" do
      before { create(:consent, :given, patient:, programme:) }

      let(:vaccination_record) do
        create(
          :vaccination_record,
          :not_administered,
          programme:,
          patient:,
          session:
        )
      end

      it "sends an email" do
        expect { send_confirmation }.to deliver_email(
          :vaccination_not_administered
        ).with(
          parent_id: parent.id,
          vaccination_record_id: vaccination_record.id,
          sent_by_user_id: sent_by.id
        )
      end

      it "sends a text message" do
        expect { send_confirmation }.to deliver_sms(
          :vaccination_not_administered
        ).with(
          parent_id: parent.id,
          vaccination_record_id: vaccination_record.id,
          sent_by_user_id: sent_by.id
        )
      end
    end

    context "when the consent was done through gillick assessment" do
      let(:vaccination_record) do
        create(
          :vaccination_record,
          programme:,
          patient:,
          session:,
          notify_parents:
        )
      end

      context "when child wants parents to be notified" do
        let(:notify_parents) { true }

        before do
          create(
            :consent,
            :given,
            :self_consent,
            :notify_parents_on_vaccination,
            patient:,
            programme:
          )
        end

        it "sends an email" do
          expect { send_confirmation }.to deliver_email(
            :vaccination_administered
          ).with(
            parent_id: parent.id,
            vaccination_record_id: vaccination_record.id,
            sent_by_user_id: sent_by.id
          )
        end

        it "sends a text message" do
          expect { send_confirmation }.to deliver_sms(
            :vaccination_administered
          ).with(
            parent_id: parent.id,
            vaccination_record_id: vaccination_record.id,
            sent_by_user_id: sent_by.id
          )
        end
      end

      context "when child doesn't want a parent to be notified" do
        before { create(:consent, :given, :self_consent, patient:, programme:) }

        let(:notify_parents) { false }

        it "doesn't send an email" do
          expect { send_confirmation }.not_to deliver_email
        end

        it "doesn't send a text message" do
          expect { send_confirmation }.not_to deliver_sms
        end
      end
    end

    context "if the patient is deceased" do
      let(:patient) { create(:patient, :deceased) }

      before { create(:consent, :given, patient:, programme:) }

      it "doesn't send an email" do
        expect { send_confirmation }.not_to deliver_email
      end

      it "doesn't send a text message" do
        expect { send_confirmation }.not_to deliver_sms
      end
    end

    context "if the patient is invalid" do
      let(:patient) { create(:patient, :invalidated) }

      before { create(:consent, :given, patient:, programme:) }

      it "doesn't send an email" do
        expect { send_confirmation }.not_to deliver_email
      end

      it "doesn't send a text message" do
        expect { send_confirmation }.not_to deliver_sms
      end
    end

    context "if the patient is restricted" do
      let(:patient) { create(:patient, :restricted) }

      before { create(:consent, :given, patient:, programme:) }

      it "doesn't send an email" do
        expect { send_confirmation }.not_to deliver_email
      end

      it "doesn't send a text message" do
        expect { send_confirmation }.not_to deliver_sms
      end
    end

    context "if the patient is archived" do
      let(:patient) { create(:patient) }

      before { create(:consent, :given, patient:, programme:) }

      it "sends an email" do
        expect { send_confirmation }.to deliver_email
      end

      it "sends a text message" do
        expect { send_confirmation }.to deliver_sms
      end
    end
  end
end
