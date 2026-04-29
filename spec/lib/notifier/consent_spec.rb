# frozen_string_literal: true

describe Notifier::Consent do
  subject(:notifier) { described_class.new(consent) }

  let(:sent_by) { create(:user) }

  let(:programme) { Programme.sample }
  let(:programmes) { [programme] }

  describe "#send_confirmation" do
    subject(:send_confirmation) do
      notifier.send_confirmation(session:, triage:, sent_by:)
    end

    let(:session) { create(:session, programmes:) }
    let(:consent) { patient.consents.first }
    let(:triage) { patient.triages.first }
    let(:patient) do
      create(:patient, :consent_given_triage_safe_to_vaccinate, session:)
    end

    context "when the parents agree, triage is required and it is safe to vaccinate" do
      it "sends an email saying triage was needed and vaccination will happen" do
        expect { send_confirmation }.to deliver_email(
          :triage_vaccination_will_happen
        ).with(
          consent_id: consent.id,
          session_id: session.id,
          sent_by_user_id: sent_by.id
        )
      end

      it "doesn't send a text message" do
        expect { send_confirmation }.not_to deliver_sms
      end
    end

    context "when programme is MMR and patient has had the 1st dose" do
      let(:programme) { Programme.mmr }

      before do
        create(:vaccination_record, patient:, programme:, session:)

        PatientStatusUpdater.call(patient:)
      end

      it "sends a different email tailored to MMR second dose" do
        expect { send_confirmation }.to deliver_email(
          :triage_vaccination_will_happen_mmr_second_dose
        ).with(
          consent_id: consent.id,
          session_id: session.id,
          sent_by_user_id: sent_by.id
        )
      end
    end

    context "when the parents agree, triage is required but it isn't safe to vaccinate" do
      let(:patient) do
        create(
          :patient,
          :consent_given_triage_needed,
          :triage_do_not_vaccinate,
          session:
        )
      end

      it "sends an email saying triage was needed but vaccination won't happen" do
        expect { send_confirmation }.to deliver_email(
          :triage_vaccination_wont_happen
        ).with(
          consent_id: consent.id,
          session_id: session.id,
          sent_by_user_id: sent_by.id
        )
      end

      it "doesn't send a text message" do
        expect { send_confirmation }.not_to deliver_sms
      end
    end

    context "triage is required and patient is invited to clinc" do
      let(:patient) do
        create(:patient, :consent_given_triage_invite_to_clinic, session:)
      end

      it "sends an email saying triage was needed but vaccination won't happen" do
        expect { send_confirmation }.to deliver_email(
          :triage_vaccination_at_clinic
        ).with(
          consent_id: consent.id,
          session_id: session.id,
          sent_by_user_id: sent_by.id
        )
      end

      it "doesn't send a text message" do
        expect { send_confirmation }.not_to deliver_sms
      end

      context "when the team is Coventry & Warwickshire Partnership NHS Trust (CWPT)" do
        let(:session) { create(:session, programmes:, team:) }
        let(:team) { create(:team, ods_code: "RYG") }

        it "enqueues an email using the CWPT-specific template" do
          expect { send_confirmation }.to deliver_email(
            :triage_vaccination_at_clinic_ryg
          ).with(
            consent_id: consent.id,
            session_id: session.id,
            sent_by_user_id: sent_by.id
          )
        end
      end

      context "when the team is Leicestershire Partnership Trust (LPT)" do
        let(:session) { create(:session, programmes:, team:) }
        let(:team) { create(:team, ods_code: "RT5") }

        it "enqueues an email using the LPT-specific template" do
          expect { send_confirmation }.to deliver_email(
            :triage_vaccination_at_clinic_rt5
          ).with(
            consent_id: consent.id,
            session_id: session.id,
            sent_by_user_id: sent_by.id
          )
        end
      end
    end

    context "when the parents agree and triage is not required" do
      let(:patient) do
        create(:patient, :consent_given_triage_not_needed, session:)
      end

      it "sends an email saying vaccination will happen" do
        expect { send_confirmation }.to deliver_email(
          :consent_confirmation_given
        ).with(
          consent_id: consent.id,
          session_id: session.id,
          sent_by_user_id: sent_by.id
        )
      end

      it "sends a text message" do
        expect { send_confirmation }.to deliver_sms(
          :consent_confirmation_given
        ).with(
          consent_id: consent.id,
          session_id: session.id,
          sent_by_user_id: sent_by.id
        )
      end
    end

    context "when the parents agree, triage is required and a decision hasn't been made" do
      let(:patient) { create(:patient, :consent_given_triage_needed, session:) }

      it "sends an email saying triage is required" do
        expect { send_confirmation }.to deliver_email(
          :consent_confirmation_triage
        ).with(
          consent_id: consent.id,
          session_id: session.id,
          sent_by_user_id: sent_by.id
        )
      end

      it "doesn't send a text message" do
        expect { send_confirmation }.not_to deliver_sms
      end
    end

    context "when the patient didn't response" do
      let(:patient) { create(:patient, :consent_not_provided, session:) }

      it "doesn't send an email" do
        expect { send_confirmation }.not_to deliver_email
      end

      it "doesn't send a text message" do
        expect { send_confirmation }.not_to deliver_sms
      end
    end

    context "when the patient self-consented" do
      let(:patient) { create(:patient, session:) }
      let(:consent) do
        create(:consent, :self_consent, :given, patient:, programme:)
      end

      it "doesn't send an email" do
        expect { send_confirmation }.not_to deliver_email
      end

      it "doesn't send a text message" do
        expect { send_confirmation }.not_to deliver_sms
      end
    end

    context "when the parents have verbally refused consent" do
      let(:patient) { create(:patient, :consent_refused, session:) }

      it "sends an email confirming they've refused consent" do
        expect { send_confirmation }.to deliver_email(
          :consent_confirmation_refused
        ).with(
          consent_id: consent.id,
          session_id: session.id,
          sent_by_user_id: sent_by.id
        )
      end

      it "sends a text message" do
        expect { send_confirmation }.to deliver_sms(
          :consent_confirmation_refused
        ).with(
          consent_id: consent.id,
          session_id: session.id,
          sent_by_user_id: sent_by.id
        )
      end
    end

    context "if the patient is deceased" do
      let(:patient) do
        create(
          :patient,
          :consent_given_triage_not_needed,
          :deceased,
          programmes:
        )
      end

      it "doesn't send an email" do
        expect { send_confirmation }.not_to deliver_email
      end

      it "doesn't send a text message" do
        expect { send_confirmation }.not_to deliver_sms
      end
    end

    context "if the patient is invalid" do
      let(:patient) do
        create(
          :patient,
          :consent_given_triage_not_needed,
          :invalidated,
          programmes:
        )
      end

      it "doesn't send an email" do
        expect { send_confirmation }.not_to deliver_email
      end

      it "doesn't send a text message" do
        expect { send_confirmation }.not_to deliver_sms
      end
    end

    context "if the patient is restricted" do
      let(:patient) do
        create(
          :patient,
          :consent_given_triage_not_needed,
          :restricted,
          programmes:
        )
      end

      it "doesn't send an email" do
        expect { send_confirmation }.not_to deliver_email
      end

      it "doesn't send a text message" do
        expect { send_confirmation }.not_to deliver_sms
      end
    end

    context "if the patient is archived" do
      let(:patient) do
        create(
          :patient,
          :consent_given_triage_not_needed,
          :archived,
          programmes:
        )
      end

      it "sends an email" do
        expect { send_confirmation }.to deliver_email(
          :consent_confirmation_given
        ).with(
          consent_id: consent.id,
          session_id: session.id,
          sent_by_user_id: sent_by.id
        )
      end

      it "sends a text message" do
        expect { send_confirmation }.to deliver_sms(
          :consent_confirmation_given
        ).with(
          consent_id: consent.id,
          session_id: session.id,
          sent_by_user_id: sent_by.id
        )
      end
    end
  end
end
