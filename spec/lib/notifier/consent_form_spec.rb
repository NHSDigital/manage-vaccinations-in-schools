# frozen_string_literal: true

describe Notifier::ConsentForm do
  subject(:notifier) { described_class.new(consent_form) }

  let(:consent_form) { create(:consent_form) }

  describe "#send_confirmation" do
    subject(:send_confirmation) { notifier.send_confirmation }

    it "sends a confirmation email" do
      programme_types = consent_form.programme_types
      disease_types =
        consent_form.consent_form_programmes.flat_map(&:disease_types).uniq

      expect { send_confirmation }.to have_delivered_email(
        :consent_confirmation_given
      ).with(consent_form:, programme_types:, disease_types:)
    end

    it "sends a consent given text" do
      programme_types = consent_form.programme_types
      disease_types =
        consent_form.consent_form_programmes.flat_map(&:disease_types).uniq

      expect { send_confirmation }.to have_delivered_sms(
        :consent_confirmation_given
      ).with(consent_form:, programme_types:, disease_types:)
    end

    context "when user refuses consent" do
      before { consent_form.update!(response: "refused") }

      it "sends an confirmation refused email" do
        expect { send_confirmation }.to have_delivered_email(
          :consent_confirmation_refused
        ).with(consent_form:)
      end

      it "sends a consent refused text" do
        expect { send_confirmation }.to have_delivered_sms(
          :consent_confirmation_refused
        ).with(consent_form:)
      end
    end

    context "when user only consents to one programme" do
      let(:menacwy_programme) { Programme.menacwy }
      let(:td_ipv_programme) { Programme.td_ipv }
      let(:programmes) { [menacwy_programme, td_ipv_programme] }
      let(:session) { create(:session, programmes:) }

      let(:consent_form) { create(:consent_form, session:) }

      before do
        consent_form.consent_form_programmes.first.update!(response: "given")
        consent_form.consent_form_programmes.second.update!(response: "refused")
        consent_form.reload
      end

      it "sends a confirmation given and a confirmation refused email" do
        expect { send_confirmation }.to have_delivered_email(
          :consent_confirmation_given
        ).with(
          consent_form:,
          programme_types: [menacwy_programme.type],
          disease_types: menacwy_programme.disease_types
        ).and have_delivered_email(:consent_confirmation_refused).with(
                consent_form:,
                programme_types: [td_ipv_programme.type],
                disease_types: td_ipv_programme.disease_types
              )
      end

      it "sends a confirmation given and a confirmation refused text" do
        expect { send_confirmation }.to have_delivered_sms(
          :consent_confirmation_given
        ).with(
          consent_form:,
          programme_types: [menacwy_programme.type],
          disease_types: menacwy_programme.disease_types
        ).and have_delivered_sms(:consent_confirmation_refused).with(
                consent_form:,
                programme_types: [td_ipv_programme.type],
                disease_types: td_ipv_programme.disease_types
              )
      end
    end

    context "when a health question is yes" do
      before { consent_form.health_answers.last.response = "yes" }

      it "sends an confirmation needs triage email" do
        programme_types = consent_form.programme_types
        disease_types =
          consent_form.consent_form_programmes.flat_map(&:disease_types).uniq

        expect { send_confirmation }.to have_delivered_email(
          :consent_confirmation_triage
        ).with(consent_form:, programme_types:, disease_types:)
      end

      it "doesn't send a text" do
        expect { send_confirmation }.not_to have_delivered_sms
      end
    end

    context "when there are no upcoming sessions" do
      let(:programmes) { [Programme.sample] }
      let(:team) { create(:team, programmes:) }
      let(:session) { create(:session, :completed, team:, programmes:) }

      let(:consent_form) do
        create(
          :consent_form,
          team:,
          school_confirmed: false,
          school: create(:gias_school, team:),
          session: session
        )
      end

      it "sends an confirmation needs triage email" do
        programme_types = consent_form.programme_types
        disease_types =
          consent_form.consent_form_programmes.flat_map(&:disease_types).uniq

        expect { send_confirmation }.to have_delivered_email(
          :consent_confirmation_clinic
        ).with(consent_form:, programme_types:, disease_types:)
      end

      it "doesn't send a text" do
        expect { send_confirmation }.not_to have_delivered_sms
      end
    end

    context "when user consents to MMRV" do
      let(:team) { create(:team, programmes: [Programme.mmr]) }
      let(:patient) do
        create(
          :patient,
          date_of_birth: Date.new(2020, 6, 1) # Eligible for MMRV
        )
      end
      let(:session) { create(:session, team:, programmes: [Programme.mmr]) }
      let(:consent_form) do
        create(
          :consent_form,
          :recorded,
          session:,
          given_name: patient.given_name,
          family_name: patient.family_name,
          date_of_birth: patient.date_of_birth
        )
      end

      before do
        consent_form.consent_form_programmes.first.update!(
          disease_types: %w[measles mumps rubella varicella],
          response: "given"
        )
      end

      it "sends confirmation email with disease_types including varicella" do
        expect { send_confirmation }.to have_delivered_email(
          :consent_confirmation_given
        ).with(
          consent_form:,
          programme_types: consent_form.programme_types,
          disease_types: %w[measles mumps rubella varicella]
        )
      end
    end
  end

  describe "#send_unknown_contact_details_warning" do
    subject(:send_unknown_contact_details_warning) do
      notifier.send_unknown_contact_details_warning(patient:)
    end

    let(:parent) do
      create(
        :parent,
        email: "existing@example.com",
        phone: "07987654321",
        phone_receive_updates: true
      )
    end
    let(:patient) { create(:patient, parents: [parent]) }
    let(:consent_form) do
      create(
        :consent_form,
        parent_email: "submitted@example.com",
        parent_phone: "07123456789"
      )
    end

    it "sends warning email and SMS to existing parent" do
      expect { send_unknown_contact_details_warning }.to have_delivered_email(
        :consent_unknown_contact_details_warning
      ).with(parent:, patient:, consent_form:).and have_delivered_sms(
              :consent_unknown_contact_details_warning
            ).with(parent:, patient:, consent_form:)
    end

    context "when parent has phone_receive_updates disabled" do
      let(:parent) do
        create(
          :parent,
          email: "existing@example.com",
          phone: "07987654321",
          phone_receive_updates: false
        )
      end

      it "sends warning email" do
        expect { send_unknown_contact_details_warning }.to have_delivered_email(
          :consent_unknown_contact_details_warning
        ).with(parent:, patient:, consent_form:)
      end

      it "does not send warning SMS" do
        expect {
          send_unknown_contact_details_warning
        }.not_to have_delivered_sms
      end
    end

    context "when multiple parents exist" do
      let(:parent2) do
        create(
          :parent,
          email: "parent2@example.com",
          phone: "07111111111",
          phone_receive_updates: true
        )
      end
      let(:patient) { create(:patient, parents: [parent, parent2]) }

      it "sends warnings to all existing parents" do
        expect { send_unknown_contact_details_warning }.to have_delivered_email(
          :consent_unknown_contact_details_warning
        ).with(parent:, patient:, consent_form:).and have_delivered_email(
                :consent_unknown_contact_details_warning
              ).with(
                parent: parent2,
                patient:,
                consent_form:
              ).and have_delivered_sms(
                      :consent_unknown_contact_details_warning
                    ).with(
                      parent:,
                      patient:,
                      consent_form:
                    ).and have_delivered_sms(
                            :consent_unknown_contact_details_warning
                          ).with(parent: parent2, patient:, consent_form:)
      end
    end
  end
end
