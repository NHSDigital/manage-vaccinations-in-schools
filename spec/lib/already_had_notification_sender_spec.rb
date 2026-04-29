# frozen_string_literal: true

describe AlreadyHadNotificationSender do
  subject(:call) do
    PatientStatusUpdater.call(patient:)
    described_class.call(vaccination_record:)
  end

  let(:academic_year) { AcademicYear.current }
  let(:session) do
    create(:session, :scheduled, programmes: [programme], academic_year:)
  end
  let(:first_parent) { create(:parent, phone_receive_updates: true) }
  let(:second_parent) { create(:parent, phone_receive_updates: false) }
  let(:patient) do
    create(:patient, parents: [first_parent, second_parent], session:)
  end
  let(:vaccination_record) do
    create(:vaccination_record, programme:, patient:, session:, performed_at:)
  end

  before { ActiveJob::Base.queue_adapter.enqueued_jobs.clear }

  shared_examples "sends no notifications" do
    it { expect { call }.not_to deliver_email }
    it { expect { call }.not_to deliver_sms }
  end

  shared_examples "sends one email to all parents with valid consents" do
    it "sends email notifications to all parents with valid consents" do
      expect { call }.to deliver_email(:vaccination_already_had).with(
        parent_id: first_parent.id,
        vaccination_record_id: vaccination_record.id,
        consent_id: first_consent.id
      ).and deliver_email(:vaccination_already_had).with(
              parent_id: second_parent.id,
              vaccination_record_id: vaccination_record.id,
              consent_id: second_consent.id
            )
    end
  end

  shared_examples "sends one SMS only to opted-in parents" do
    it "sends SMS notifications to parents who opted in for updates" do
      expect { call }.to deliver_sms(:vaccination_already_had).with(
        parent_id: first_parent.id,
        vaccination_record_id: vaccination_record.id,
        consent_id: first_consent.id
      )
    end

    it "doesn't send SMS notifications to parents who haven't opted in" do
      expect { call }.not_to deliver_sms(:vaccination_already_had).with(
        parent_id: second_parent.id,
        vaccination_record_id: vaccination_record.id,
        consent_id: second_consent.id
      )
    end
  end

  shared_context "with valid consents" do
    let(:first_consent) do
      create(
        :consent,
        :given,
        patient:,
        programme:,
        parent: first_parent,
        academic_year:
      )
    end
    let(:second_consent) do
      create(
        :consent,
        :given,
        patient:,
        programme:,
        parent: second_parent,
        academic_year:
      )
    end
  end

  describe "#call" do
    context "for a seasonal programme" do
      let(:programme) { Programme.flu }

      context "when vaccination record is not sourced from service" do
        include_context "with valid consents"

        before do
          allow(vaccination_record).to receive(
            :sourced_from_service?
          ).and_return(false)
        end

        context "when the patient was not previously considered vaccinated and has valid consents" do
          let(:performed_at) { Time.zone.today }

          include_examples "sends one email to all parents with valid consents"
          include_examples "sends one SMS only to opted-in parents"
        end

        context "when the patient is not considered vaccinated" do
          let(:performed_at) { 1.year.ago }

          include_examples "sends no notifications"
        end
      end
    end

    context "for a non-seasonal programme" do
      let(:programme) { Programme.hpv }
      let(:performed_at) { 1.year.ago }

      context "when vaccination record is sourced from service" do
        include_context "with valid consents"

        before do
          allow(vaccination_record).to receive(
            :sourced_from_service?
          ).and_return(true)
        end

        include_examples "sends no notifications"
      end

      context "when vaccination record is not sourced from service" do
        before do
          allow(vaccination_record).to receive(
            :sourced_from_service?
          ).and_return(false)
        end

        context "when patient is already considered vaccinated" do
          before { create(:vaccination_record, programme:, patient:, session:) }

          include_examples "sends no notifications"
        end

        context "when patient was not previously considered vaccinated and has valid consents" do
          include_context "with valid consents"

          include_examples "sends one email to all parents with valid consents"
          include_examples "sends one SMS only to opted-in parents"

          it "updates consents with patient_already_vaccinated_notification_sent_at" do
            expect(
              first_consent.patient_already_vaccinated_notification_sent_at
            ).to be_nil
            expect(
              second_consent.patient_already_vaccinated_notification_sent_at
            ).to be_nil

            call

            expect(
              first_consent.reload.patient_already_vaccinated_notification_sent_at
            ).to be_present
            expect(
              second_consent.reload.patient_already_vaccinated_notification_sent_at
            ).to be_present
          end

          context "with invalidated consents" do
            before do
              first_consent.update!(
                invalidated_at: 1.day.ago,
                notes: "Some notes"
              )
            end

            it "ignores invalidated consents" do
              expect { call }.not_to deliver_email.with(parent: first_parent)
            end
          end

          context "with refused consents" do
            before do
              first_consent.update!(
                response: :refused,
                reason_for_refusal: :personal_choice
              )
            end

            it "ignores refused consents" do
              expect { call }.not_to deliver_email.with(parent: first_parent)
            end
          end

          context "with consents already notified after this vaccination record was created" do
            before do
              first_consent.update!(
                patient_already_vaccinated_notification_sent_at:
                  vaccination_record.created_at + 1.hour
              )
            end

            it "excludes consents notified after this vaccination record" do
              expect { call }.not_to deliver_email.with(parent: first_parent)
            end
          end

          context "with consents notified before this vaccination record was created" do
            before do
              first_consent.update!(
                patient_already_vaccinated_notification_sent_at:
                  vaccination_record.created_at - 1.hour
              )
            end

            include_examples "sends one email to all parents with valid consents"
          end
        end

        context "when no valid consents exist" do
          include_examples "sends no notifications"
        end

        context "when another vaccination record has been created at almost the same time" do
          include_context "with valid consents"

          before do
            create(
              :vaccination_record,
              programme:,
              patient:,
              session:,
              performed_at:
            )
          end

          include_examples "sends one email to all parents with valid consents"
          include_examples "sends one SMS only to opted-in parents"
        end
      end
    end
  end
end
