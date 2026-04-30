# frozen_string_literal: true

# == Schema Information
#
# Table name: session_notifications
#
#  id              :bigint           not null, primary key
#  sent_at         :datetime         not null
#  session_date    :date             not null
#  type            :integer          not null
#  patient_id      :bigint           not null
#  sent_by_user_id :bigint
#  session_id      :bigint           not null
#
# Indexes
#
#  idx_on_patient_id_session_id_session_date_f7f30a3aa3  (patient_id,session_id,session_date)
#  index_session_notifications_on_sent_by_user_id        (sent_by_user_id)
#  index_session_notifications_on_session_id             (session_id)
#
# Foreign Keys
#
#  fk_rails_...  (patient_id => patients.id)
#  fk_rails_...  (sent_by_user_id => users.id)
#  fk_rails_...  (session_id => sessions.id)
#
describe SessionNotification do
  describe "#create_and_send!" do
    subject(:create_and_send!) do
      travel_to(today) do
        described_class.create_and_send!(
          patient:,
          session:,
          session_date:,
          type:,
          current_user:
        )
      end
    end

    let(:today) { Date.new(2024, 1, 1) }

    let(:parents) { create_list(:parent, 2) }
    let(:patient) { create(:patient, parents:, year_group: 10, session:) }
    let(:programme) { Programme.td_ipv }
    let(:programmes) { [programme] }
    let(:programme_types) { programmes.map(&:type) }
    let(:team) { create(:team, programmes:) }
    let(:location) { create(:gias_school, team:) }
    let(:session) { create(:session, location:, programmes:, team:) }
    let(:session_date) { session.dates.min }
    let(:current_user) { create(:user) }

    let(:delivery_params) do
      {
        parent_id: parent.id,
        patient_id: patient.id,
        session_id: session.id,
        sent_by_user_id: current_user.id
      }
    end

    context "with a school reminder" do
      let(:type) { :school_reminder }

      let(:parent) { parents.first }

      before do
        create(:consent, :given, patient:, parent:, programme:)
        create(:patient_programme_status, :due_injection, patient:, programme:)
      end

      it "creates a record" do
        expect { create_and_send! }.to change(described_class, :count).by(1)

        session_notification = described_class.last
        expect(session_notification).to be_school_reminder
        expect(session_notification.session).to eq(session)
        expect(session_notification.patient).to eq(patient)
        expect(session_notification.sent_at).to eq(today)
      end

      it "enqueues an email per parent who gave consent" do
        expect { create_and_send! }.to deliver_email(
          :session_school_reminder
        ).with(delivery_params.merge(programme_types:))
      end

      it "enqueues a text per parent" do
        expect { create_and_send! }.to deliver_sms(
          :session_school_reminder
        ).with(delivery_params.merge(programme_types:))
      end

      context "when parent doesn't want to receive updates by text" do
        before { parents.each { it.update!(phone_receive_updates: false) } }

        it "doesn't enqueues a text" do
          expect { create_and_send! }.not_to deliver_sms
        end
      end

      context "with multiple programmes but only one eligible for vaccination" do
        let(:consented_programmes) { [programme] }

        # No consent for MenACWY
        let(:programmes) { consented_programmes + [Programme.menacwy] }

        it "enqueues an email per parent who gave consent" do
          expect { create_and_send! }.to deliver_email(
            :session_school_reminder
          ).with(
            delivery_params.merge(
              programme_types: consented_programmes.map(&:type)
            )
          )
        end

        it "enqueues a text per parent" do
          expect { create_and_send! }.to deliver_sms(
            :session_school_reminder
          ).with(
            delivery_params.merge(
              programme_types: consented_programmes.map(&:type)
            )
          )
        end
      end
    end
  end
end
