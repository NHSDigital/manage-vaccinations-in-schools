# frozen_string_literal: true

describe Notifier::Patient do
  subject(:notifier) { described_class.new(patient) }

  let(:sent_by) { create(:user) }

  describe "#send_consent_request" do
    let(:today) { Date.new(2024, 1, 1) }

    let(:parents) { create_list(:parent, 2) }
    let(:patient) { create(:patient, parents:, session:) }
    let(:programmes) { [Programme.hpv] }
    let(:disease_types) { programmes.flat_map(&:disease_types).uniq.presence }
    let(:programme_types) { programmes.map(&:type) }
    let(:team) { create(:team, programmes:) }
    let(:send_consent_requests_at) { nil }
    let(:session) do
      create(:session, location:, programmes:, team:, send_consent_requests_at:)
    end
    let(:team_location) { session.team_location }

    context "with a session" do
      subject(:send_consent_request) do
        travel_to(today) do
          notifier.send_consent_request(programmes, session:, sent_by:)
        end
      end

      context "with a school location" do
        let(:location) { create(:gias_school, team:) }

        it "creates a record" do
          expect { send_consent_request }.to change(
            ConsentNotification,
            :count
          ).by(1)

          consent_notification = ConsentNotification.last
          expect(consent_notification).not_to be_an_initial_reminder
          expect(consent_notification.programme_types).to eq(programme_types)
          expect(consent_notification.patient).to eq(patient)
          expect(consent_notification.sent_at).to eq(today)
        end

        context "when the consent request was scheduled for the future" do
          let(:send_consent_requests_at) { today + 1.day }

          it "updates the programme status after sending the request" do
            travel_to(today) do
              PatientStatusUpdater.call(patient:)

              expect(
                patient.programme_status(
                  programmes.first,
                  academic_year: session.academic_year
                )
              ).to be_needs_consent_request_scheduled

              notifier.send_consent_request(programmes, session:, sent_by:)

              expect(PatientStatusUpdaterJob).to have_enqueued_sidekiq_job(
                patient.id
              )

              PatientStatusUpdaterJob.drain

              expect(
                patient.programme_status(
                  programmes.first,
                  academic_year: session.academic_year
                ).reload
              ).to be_needs_consent_no_response
            end
          end
        end

        it "enqueues an email per parent" do
          expect { send_consent_request }.to deliver_email(
            :consent_school_request_hpv
          ).with(
            disease_types:,
            parent: parents.first,
            patient:,
            programme_types:,
            session:,
            sent_by:
          ).and deliver_email(:consent_school_request_hpv).with(
                  disease_types:,
                  parent: parents.second,
                  patient:,
                  programme_types:,
                  session:,
                  sent_by:
                )
        end

        it "enqueues a text per parent" do
          expect { send_consent_request }.to deliver_sms(
            :consent_school_request
          ).with(
            disease_types:,
            parent: parents.first,
            patient:,
            programme_types:,
            session:,
            sent_by:
          ).and deliver_sms(:consent_school_request).with(
                  disease_types:,
                  parent: parents.second,
                  patient:,
                  programme_types:,
                  session:,
                  sent_by:
                )
        end

        context "when parent doesn't want to receive updates by text" do
          let(:parent) { parents.first }

          before { parent.update!(phone_receive_updates: false) }

          it "still enqueues a text" do
            expect { send_consent_request }.to deliver_sms(
              :consent_school_request
            ).with(
              disease_types:,
              parent:,
              patient:,
              programme_types:,
              session:,
              sent_by:
            )
          end
        end

        context "for Td/IPV and MenACWY programmes" do
          let(:programmes) { [Programme.menacwy, Programme.td_ipv] }

          it "enqueues an email per parent" do
            expect { send_consent_request }.to deliver_email(
              :consent_school_request_doubles
            ).twice
          end

          it "enqueues an sms per parent" do
            expect { send_consent_request }.to deliver_sms(
              :consent_school_request
            ).twice
          end
        end

        context "for the flu programme" do
          let(:programmes) { [Programme.flu] }

          it "enqueues an email per parent" do
            expect { send_consent_request }.to deliver_email(
              :consent_school_request_flu
            ).twice
          end

          it "enqueues an sms per parent" do
            expect { send_consent_request }.to deliver_sms(
              :consent_school_request
            ).twice
          end
        end

        context "for the MMR(V) programme" do
          let(:programmes) { [Programme.mmr] }

          context "if the child received their first dose under self-consent and doesn't want parents notified" do
            before do
              create(
                :vaccination_record,
                programme: Programme.mmr,
                patient:,
                notify_parents: false
              )
            end

            it "does not enqueue an email" do
              expect { send_consent_request }.not_to deliver_email
            end

            it "does not enqueue an SMS" do
              expect { send_consent_request }.not_to deliver_sms
            end
          end

          context "when patient is eligible for MMRV" do
            before do
              allow(patient).to receive(:eligible_for_mmrv?).and_return(true)
            end

            it "enqueues an email per parent" do
              expect { send_consent_request }.to deliver_email(
                :consent_school_request_mmrv
              ).twice
            end

            it "enqueues an sms per parent" do
              expect { send_consent_request }.to deliver_sms(
                :consent_school_request_mmr
              ).twice
            end

            context "when session is set to send outbreak requests" do
              let(:session) do
                create(:session, location:, programmes:, team:, outbreak: true)
              end

              it "enqueues an outbreak email per parent" do
                expect { send_consent_request }.to deliver_email(
                  :consent_school_request_mmrv_outbreak
                ).twice
              end

              it "enqueues an sms" do
                expect { send_consent_request }.to deliver_sms(
                  :consent_school_request_mmr
                ).twice
              end
            end
          end

          context "when patient is not eligible for MMRV" do
            before do
              allow(patient).to receive(:eligible_for_mmrv?).and_return(false)
            end

            it "enqueues an email per parent" do
              expect { send_consent_request }.to deliver_email(
                :consent_school_request_mmr
              ).twice
            end

            it "enqueues an sms" do
              expect { send_consent_request }.to deliver_sms(
                :consent_school_request_mmr
              ).twice
            end

            context "when session is set to send outbreak style requests" do
              let(:session) do
                create(:session, location:, programmes:, team:, outbreak: true)
              end

              it "enqueues an outbreak email per parent" do
                expect { send_consent_request }.to deliver_email(
                  :consent_school_request_mmr_outbreak
                ).twice
              end

              it "enqueues an sms" do
                expect { send_consent_request }.to deliver_sms(
                  :consent_school_request_mmr
                ).twice
              end
            end
          end
        end
      end

      context "with a clinic location" do
        let(:location) { create(:generic_clinic, team:) }

        it "creates a record" do
          expect { send_consent_request }.to change(
            ConsentNotification,
            :count
          ).by(1)

          consent_notification = ConsentNotification.last
          expect(consent_notification).to be_a_request
          expect(consent_notification.programmes).to eq(programmes)
          expect(consent_notification.patient).to eq(patient)
          expect(consent_notification.sent_at).to eq(today)
        end

        it "enqueues an email per parent" do
          expect { send_consent_request }.to deliver_email(
            :consent_clinic_request
          ).with(
            disease_types:,
            parent: parents.first,
            patient:,
            programme_types:,
            session:,
            sent_by:
          ).and deliver_email(:consent_clinic_request).with(
                  disease_types:,
                  parent: parents.second,
                  patient:,
                  programme_types:,
                  session:,
                  sent_by:
                )
        end

        it "enqueues a text per parent" do
          expect { send_consent_request }.to deliver_sms(
            :consent_clinic_request
          ).with(
            disease_types:,
            parent: parents.first,
            patient:,
            programme_types:,
            session:,
            sent_by:
          ).and deliver_sms(:consent_clinic_request).with(
                  disease_types:,
                  parent: parents.second,
                  patient:,
                  programme_types:,
                  session:,
                  sent_by:
                )
        end

        context "when parent doesn't want to receive updates by text" do
          let(:parent) { parents.first }

          before { parent.update!(phone_receive_updates: false) }

          it "still enqueues a text" do
            expect { send_consent_request }.to deliver_sms(
              :consent_clinic_request
            ).with(
              disease_types:,
              parent:,
              patient:,
              programme_types:,
              session:,
              sent_by:
            )
          end
        end
      end
    end

    context "with a team location" do
      subject(:send_consent_request) do
        travel_to(today) do
          notifier.send_consent_request(programmes, team_location:, sent_by:)
        end
      end

      context "with a school location" do
        let(:location) { create(:gias_school, team:) }

        it "creates a record" do
          expect { send_consent_request }.to change(
            ConsentNotification,
            :count
          ).by(1)

          consent_notification = ConsentNotification.last
          expect(consent_notification).not_to be_an_initial_reminder
          expect(consent_notification.programme_types).to eq(programme_types)
          expect(consent_notification.patient).to eq(patient)
          expect(consent_notification.sent_at).to eq(today)
        end

        it "enqueues an email per parent" do
          expect { send_consent_request }.to deliver_email(
            :consent_school_request_hpv
          ).with(
            disease_types:,
            parent: parents.first,
            patient:,
            programme_types:,
            team_location:,
            sent_by:
          ).and deliver_email(:consent_school_request_hpv).with(
                  disease_types:,
                  parent: parents.second,
                  patient:,
                  programme_types:,
                  team_location:,
                  sent_by:
                )
        end

        it "enqueues a text per parent" do
          expect { send_consent_request }.to deliver_sms(
            :consent_school_request
          ).with(
            disease_types:,
            parent: parents.first,
            patient:,
            programme_types:,
            team_location:,
            sent_by:
          ).and deliver_sms(:consent_school_request).with(
                  disease_types:,
                  parent: parents.second,
                  patient:,
                  programme_types:,
                  team_location:,
                  sent_by:
                )
        end

        context "when parent doesn't want to receive updates by text" do
          let(:parent) { parents.first }

          before { parent.update!(phone_receive_updates: false) }

          it "still enqueues a text" do
            expect { send_consent_request }.to deliver_sms(
              :consent_school_request
            ).with(
              disease_types:,
              parent:,
              patient:,
              programme_types:,
              team_location:,
              sent_by:
            )
          end
        end

        context "for Td/IPV and MenACWY programmes" do
          let(:programmes) { [Programme.menacwy, Programme.td_ipv] }

          it "enqueues an email per parent" do
            expect { send_consent_request }.to deliver_email(
              :consent_school_request_doubles
            ).twice
          end

          it "enqueues an sms per parent" do
            expect { send_consent_request }.to deliver_sms(
              :consent_school_request
            ).twice
          end
        end

        context "for the flu programme" do
          let(:programmes) { [Programme.flu] }

          it "enqueues an email per parent" do
            expect { send_consent_request }.to deliver_email(
              :consent_school_request_flu
            ).twice
          end

          it "enqueues an sms per parent" do
            expect { send_consent_request }.to deliver_sms(
              :consent_school_request
            ).twice
          end
        end

        context "for the MMR(V) programme" do
          let(:programmes) { [Programme.mmr] }

          context "if the child received their first dose under self-consent and doesn't want parents notified" do
            before do
              create(
                :vaccination_record,
                programme: Programme.mmr,
                patient:,
                notify_parents: false
              )
            end

            it "does not enqueue an email" do
              expect { send_consent_request }.not_to deliver_email
            end

            it "does not enqueue an SMS" do
              expect { send_consent_request }.not_to deliver_sms
            end
          end

          context "when patient is eligible for MMRV" do
            before do
              allow(patient).to receive(:eligible_for_mmrv?).and_return(true)
            end

            it "enqueues an email per parent" do
              expect { send_consent_request }.to deliver_email(
                :consent_school_request_mmrv
              ).twice
            end

            it "enqueues an sms per parent" do
              expect { send_consent_request }.to deliver_sms(
                :consent_school_request_mmr
              ).twice
            end
          end

          context "when patient is not eligible for MMRV" do
            before do
              allow(patient).to receive(:eligible_for_mmrv?).and_return(false)
            end

            it "enqueues an email per parent" do
              expect { send_consent_request }.to deliver_email(
                :consent_school_request_mmr
              ).twice
            end

            it "enqueues an sms" do
              expect { send_consent_request }.to deliver_sms(
                :consent_school_request_mmr
              ).twice
            end
          end
        end
      end

      context "with a clinic location" do
        let(:location) { create(:generic_clinic, team:) }

        it "creates a record" do
          expect { send_consent_request }.to change(
            ConsentNotification,
            :count
          ).by(1)

          consent_notification = ConsentNotification.last
          expect(consent_notification).to be_a_request
          expect(consent_notification.programmes).to eq(programmes)
          expect(consent_notification.patient).to eq(patient)
          expect(consent_notification.sent_at).to eq(today)
        end

        it "enqueues an email per parent" do
          expect { send_consent_request }.to deliver_email(
            :consent_clinic_request
          ).with(
            disease_types:,
            parent: parents.first,
            patient:,
            programme_types:,
            team_location:,
            sent_by:
          ).and deliver_email(:consent_clinic_request).with(
                  disease_types:,
                  parent: parents.second,
                  patient:,
                  programme_types:,
                  team_location:,
                  sent_by:
                )
        end

        it "enqueues a text per parent" do
          expect { send_consent_request }.to deliver_sms(
            :consent_clinic_request
          ).with(
            disease_types:,
            parent: parents.first,
            patient:,
            programme_types:,
            team_location:,
            sent_by:
          ).and deliver_sms(:consent_clinic_request).with(
                  disease_types:,
                  parent: parents.second,
                  patient:,
                  programme_types:,
                  team_location:,
                  sent_by:
                )
        end

        context "when parent doesn't want to receive updates by text" do
          let(:parent) { parents.first }

          before { parent.update!(phone_receive_updates: false) }

          it "still enqueues a text" do
            expect { send_consent_request }.to deliver_sms(
              :consent_clinic_request
            ).with(
              disease_types:,
              parent:,
              patient:,
              programme_types:,
              team_location:,
              sent_by:
            )
          end
        end
      end
    end
  end

  describe "#send_consent_reminder" do
    subject(:send_consent_reminder) do
      travel_to(today) do
        notifier.send_consent_reminder(programmes, session:, sent_by:)
      end
    end

    before { patient.strict_loading!(false) }

    let(:today) { Date.new(2024, 1, 1) }

    let(:parents) { create_list(:parent, 2) }
    let(:patient) { create(:patient, parents:, session:) }
    let(:programmes) { [Programme.hpv] }
    let(:disease_types) { programmes.flat_map(&:disease_types).uniq.presence }
    let(:programme_types) { programmes.map(&:type) }
    let(:team) { create(:team, programmes:) }
    let(:location) { create(:gias_school, team:) }
    let(:session) { create(:session, location:, programmes:, team:) }

    context "without an initial reminder" do
      it "creates a record" do
        expect { send_consent_reminder }.to change(
          ConsentNotification,
          :count
        ).by(1)

        consent_notification = ConsentNotification.last
        expect(consent_notification).to be_an_initial_reminder
        expect(consent_notification.programmes).to eq(programmes)
        expect(consent_notification.patient).to eq(patient)
        expect(consent_notification.sent_at).to eq(today)
      end

      it "enqueues an email per parent with the correct args" do
        expect { send_consent_reminder }.to deliver_email(
          :consent_school_reminder_hpv
        ).with(
          disease_types:,
          parent: parents.first,
          patient:,
          programme_types:,
          session:,
          sent_by:
        ).and deliver_email(:consent_school_reminder_hpv).with(
                disease_types:,
                parent: parents.second,
                patient:,
                programme_types:,
                session:,
                sent_by:
              )
      end

      it "enqueues a text per parent" do
        expect { send_consent_reminder }.to deliver_sms(
          :consent_school_reminder
        ).with(
          disease_types:,
          parent: parents.first,
          patient:,
          programme_types:,
          session:,
          sent_by:
        ).and deliver_sms(:consent_school_reminder).with(
                disease_types:,
                parent: parents.second,
                patient:,
                programme_types:,
                session:,
                sent_by:
              )
      end

      context "when parent doesn't want to receive updates by text" do
        let(:parent) { parents.first }

        before { parent.update!(phone_receive_updates: false) }

        it "still enqueues a text" do
          expect { send_consent_reminder }.to deliver_sms(
            :consent_school_reminder
          ).with(
            disease_types:,
            parent:,
            patient:,
            programme_types:,
            session:,
            sent_by:
          )
        end
      end

      context "with Td/IPV and MenACWY programmes" do
        let(:programmes) { [Programme.menacwy, Programme.td_ipv] }

        it "enqueues an email per parent" do
          expect { send_consent_reminder }.to deliver_email(
            :consent_school_reminder_doubles
          ).twice
        end

        it "enqueues an sms per parent" do
          expect { send_consent_reminder }.to deliver_sms(
            :consent_school_reminder
          ).twice
        end
      end

      context "with the flu programme" do
        let(:programmes) { [Programme.flu] }

        it "enqueues an email per parent" do
          expect { send_consent_reminder }.to deliver_email(
            :consent_school_reminder_flu
          ).twice
        end

        it "enqueues an sms per parent" do
          expect { send_consent_reminder }.to deliver_sms(
            :consent_school_reminder
          ).twice
        end
      end

      context "for the MMR(V) programme" do
        let(:programmes) { [Programme.mmr] }

        before do
          allow(patient).to receive(:eligible_for_mmrv?).and_return(false)
        end

        it "enqueues an email" do
          expect { send_consent_reminder }.to deliver_email(
            :consent_school_reminder_mmr
          ).twice
        end

        it "enqueues an sms" do
          expect { send_consent_reminder }.to deliver_sms(
            :consent_school_reminder
          ).twice
        end

        context "with a session that is set to send outbreak style requests" do
          let(:session) do
            create(:session, location:, programmes:, team:, outbreak: true)
          end

          it "enqueues an email" do
            expect { send_consent_reminder }.to deliver_email(
              :consent_school_reminder_mmr
            ).twice
          end

          it "enqueues an sms" do
            expect { send_consent_reminder }.to deliver_sms(
              :consent_school_reminder
            ).twice
          end
        end

        context "and a patient that is eligible for MMRV" do
          before do
            allow(patient).to receive(:eligible_for_mmrv?).and_return(true)
          end

          it "enqueues an email" do
            expect { send_consent_reminder }.to deliver_email(
              :consent_school_reminder_mmrv
            ).twice
          end

          it "enqueues an sms" do
            expect { send_consent_reminder }.to deliver_sms(
              :consent_school_reminder
            ).twice
          end

          context "with a session that is set to send outbreak style requests" do
            let(:session) do
              create(:session, location:, programmes:, team:, outbreak: true)
            end

            it "enqueues an email" do
              expect { send_consent_reminder }.to deliver_email(
                :consent_school_reminder_mmrv
              ).twice
            end

            it "enqueues an sms" do
              expect { send_consent_reminder }.to deliver_sms(
                :consent_school_reminder
              ).twice
            end
          end
        end

        context "if the child received their first dose under self-consent and doesn't want parents notified" do
          before do
            create(
              :vaccination_record,
              programme: Programme.mmr,
              patient:,
              notify_parents: false
            )
          end

          it "does not enqueue an email" do
            expect { send_consent_reminder }.not_to deliver_email
          end

          it "does not enqueue an SMS" do
            expect { send_consent_reminder }.not_to deliver_sms
          end
        end
      end
    end

    context "when the patient has already got an initial reminder from a previous academic year" do
      before do
        session =
          create(:session, programmes:, academic_year: AcademicYear.previous)
        create(
          :consent_notification,
          :initial_reminder,
          patient:,
          programmes:,
          session:
        )
      end

      it "creates a record" do
        expect { send_consent_reminder }.to change(
          ConsentNotification,
          :count
        ).by(1)

        consent_notification = ConsentNotification.last
        expect(consent_notification).to be_an_initial_reminder
        expect(consent_notification.programmes).to eq(programmes)
        expect(consent_notification.patient).to eq(patient)
        expect(consent_notification.sent_at).to eq(today)
      end
    end

    context "when the patient has already got an initial reminder" do
      before do
        create(:consent_notification, :initial_reminder, patient:, programmes:)
      end

      it "creates a record" do
        expect { send_consent_reminder }.to change(
          ConsentNotification,
          :count
        ).by(1)

        consent_notification = ConsentNotification.last
        expect(consent_notification).to be_a_subsequent_reminder
        expect(consent_notification.programmes).to eq(programmes)
        expect(consent_notification.patient).to eq(patient)
        expect(consent_notification.sent_at).to eq(today)
      end

      it "enqueues an email per parent" do
        expect { send_consent_reminder }.to deliver_email(
          :consent_school_reminder_hpv
        ).with(
          disease_types:,
          parent: parents.first,
          patient:,
          programme_types:,
          session:,
          sent_by:
        ).and deliver_email(:consent_school_reminder_hpv).with(
                disease_types:,
                parent: parents.second,
                patient:,
                programme_types:,
                session:,
                sent_by:
              )
      end

      it "enqueues a text per parent" do
        expect { send_consent_reminder }.to deliver_sms(
          :consent_school_reminder
        ).with(
          disease_types:,
          parent: parents.first,
          patient:,
          programme_types:,
          session:,
          sent_by:
        ).and deliver_sms(:consent_school_reminder).with(
                disease_types:,
                parent: parents.second,
                patient:,
                programme_types:,
                session:,
                sent_by:
              )
      end

      context "when parent doesn't want to receive updates by text" do
        let(:parent) { parents.first }

        before { parent.update!(phone_receive_updates: false) }

        it "still enqueues a text" do
          expect { send_consent_reminder }.to deliver_sms(
            :consent_school_reminder
          ).with(
            disease_types:,
            parent:,
            patient:,
            programme_types:,
            session:,
            sent_by:
          )
        end
      end

      context "with Td/IPV and MenACWY programmes" do
        let(:programmes) { [Programme.menacwy, Programme.td_ipv] }

        it "enqueues an email per parent" do
          expect { send_consent_reminder }.to deliver_email(
            :consent_school_reminder_doubles
          ).twice
        end

        it "enqueues an sms per parent" do
          expect { send_consent_reminder }.to deliver_sms(
            :consent_school_reminder
          ).twice
        end
      end

      context "with the flu programme" do
        let(:programmes) { [Programme.flu] }

        it "enqueues an email per parent" do
          expect { send_consent_reminder }.to deliver_email(
            :consent_school_reminder_flu
          ).twice
        end

        it "enqueues an sms per parent" do
          expect { send_consent_reminder }.to deliver_sms(
            :consent_school_reminder
          ).twice
        end
      end

      context "with an MMR(V) programme" do
        let(:programmes) { [Programme.mmr] }

        context "and a patient that is not eligible for MMRV" do
          before do
            allow(patient).to receive(:eligible_for_mmrv?).and_return(false)
          end

          it "enqueues an email" do
            expect { send_consent_reminder }.to deliver_email(
              :consent_school_reminder_mmr
            ).twice
          end

          it "enqueues an sms" do
            expect { send_consent_reminder }.to deliver_sms(
              :consent_school_reminder
            ).twice
          end

          context "with a session that is set to send outbreak style requests" do
            let(:session) do
              create(:session, location:, programmes:, team:, outbreak: true)
            end

            it "enqueues an email" do
              expect { send_consent_reminder }.to deliver_email(
                :consent_school_reminder_mmr
              ).twice
            end

            it "enqueues an sms" do
              expect { send_consent_reminder }.to deliver_sms(
                :consent_school_reminder
              ).twice
            end
          end
        end

        context "and a patient that is eligible for MMRV" do
          before do
            allow(patient).to receive(:eligible_for_mmrv?).and_return(true)
          end

          it "enqueues an email" do
            expect { send_consent_reminder }.to deliver_email(
              :consent_school_reminder_mmrv
            ).twice
          end

          it "enqueues an sms" do
            expect { send_consent_reminder }.to deliver_sms(
              :consent_school_reminder
            ).twice
          end

          context "with a session that is set to send outbreak style requests" do
            let(:session) do
              create(:session, location:, programmes:, team:, outbreak: true)
            end

            it "enqueues an email" do
              expect { send_consent_reminder }.to deliver_email(
                :consent_school_reminder_mmrv
              ).twice
            end

            it "enqueues an sms" do
              expect { send_consent_reminder }.to deliver_sms(
                :consent_school_reminder
              ).twice
            end
          end
        end
      end
    end
  end

  describe "#can_send_clinic_invitation?" do
    subject(:can_send_clinic_invitation?) do
      notifier.can_send_clinic_invitation?(
        programmes,
        team:,
        academic_year:,
        include_vaccinated_programmes:,
        include_already_invited_programmes:
      )
    end

    around { |example| travel_to(today) { example.run } }

    let(:today) { Date.new(2024, 1, 1) }

    let(:parents) { create_list(:parent, 2) }
    let(:patient) { create(:patient, session:, parents:, year_group: 10) }
    let(:programmes) { [Programme.td_ipv] }
    let(:programme_types) { programmes.map(&:type) }
    let(:team) { create(:team, programmes:) }
    let(:location) { create(:gias_school, team:) }
    let(:session) { create(:session, location:, programmes:, team:) }
    let(:academic_year) { AcademicYear.current }
    let(:include_vaccinated_programmes) { false }
    let(:include_already_invited_programmes) { true }

    before { PatientStatusUpdater.call(patient:) }

    context "for an ineligible programme" do
      let(:patient) { create(:patient, parents:, year_group: 2) }

      it { should be(false) }
    end

    context "without an invitation already" do
      it { should be(true) }

      context "if the child received their first dose under self-consent and doesn't want parents notified" do
        let(:programmes) { [Programme.mmr] }

        before do
          create(
            :vaccination_record,
            programme: Programme.mmr,
            patient:,
            notify_parents: false
          )
        end

        it { should be(false) }
      end

      context "when the session administers two programmes but the patient only needs one" do
        let(:programmes) { [Programme.flu, Programme.hpv] }

        before do
          create(:vaccination_record, patient:, programme: programmes.first)
          PatientStatusUpdater.call(patient:)
        end

        it { should be(true) }
      end
    end

    context "when already invited" do
      before do
        create(
          :clinic_notification,
          :initial_invitation,
          patient:,
          team:,
          academic_year:,
          programmes:
        )
      end

      it { should be(true) }

      context "and not including already invited programmes" do
        let(:include_already_invited_programmes) { false }

        it { should be(false) }
      end
    end

    context "when already invited to one of two possible programmes" do
      let(:programmes) { [Programme.flu, Programme.hpv] }

      before do
        create(
          :clinic_notification,
          :initial_invitation,
          patient:,
          team:,
          academic_year:,
          programmes: [Programme.flu]
        )
      end

      it { should be(true) }

      context "and not including already invited programmes" do
        let(:include_already_invited_programmes) { false }

        it { should be(true) }
      end
    end
  end

  describe "#send_clinic_invitation" do
    subject(:send_clinic_invitation) do
      notifier.send_clinic_invitation(
        programmes,
        team:,
        academic_year:,
        sent_by:,
        include_vaccinated_programmes:,
        include_already_invited_programmes:
      )
    end

    around { |example| travel_to(today) { example.run } }

    let(:today) { Date.new(2024, 1, 1) }

    let(:parents) { create_list(:parent, 2) }
    let(:patient) { create(:patient, session:, parents:, year_group: 10) }
    let(:programmes) { [Programme.td_ipv] }
    let(:programme_types) { programmes.map(&:type) }
    let(:team) { create(:team, programmes:) }
    let(:location) { create(:gias_school, team:) }
    let(:session) { create(:session, location:, programmes:, team:) }
    let(:academic_year) { AcademicYear.current }
    let(:include_vaccinated_programmes) { false }
    let(:include_already_invited_programmes) { true }

    before { PatientStatusUpdater.call(patient:) }

    context "without an invitation already" do
      it "creates a record" do
        expect { send_clinic_invitation }.to change(
          ClinicNotification,
          :count
        ).by(1)

        clinic_notification = ClinicNotification.last
        expect(clinic_notification).to be_initial_invitation
        expect(clinic_notification.team).to eq(team)
        expect(clinic_notification.patient).to eq(patient)
        expect(clinic_notification.sent_at).to eq(today)
      end

      it "enqueues an email per parent" do
        expect { send_clinic_invitation }.to deliver_email(
          :clinic_initial_invitation
        ).with(
          parent: parents.first,
          patient:,
          programme_types:,
          team:,
          academic_year:,
          sent_by:
        ).and deliver_email(:clinic_initial_invitation).with(
                parent: parents.second,
                patient:,
                programme_types:,
                team:,
                academic_year:,
                sent_by:
              )
      end

      it "enqueues a text per parent" do
        expect { send_clinic_invitation }.to deliver_sms(
          :clinic_initial_invitation
        ).with(
          parent: parents.first,
          patient:,
          programme_types:,
          team:,
          academic_year:,
          sent_by:
        ).and deliver_sms(:clinic_initial_invitation).with(
                parent: parents.second,
                patient:,
                programme_types:,
                team:,
                academic_year:,
                sent_by:
              )
      end

      context "if the child received their first dose under self-consent and doesn't want parents notified" do
        let(:programmes) { [Programme.mmr] }

        before do
          create(
            :vaccination_record,
            programme: Programme.mmr,
            patient:,
            notify_parents: false
          )
        end

        it "does not enqueue an email" do
          expect { send_clinic_invitation }.not_to deliver_email
        end

        it "does not enqueue an SMS" do
          expect { send_clinic_invitation }.not_to deliver_sms
        end
      end

      context "when the session administers two programmes but the patient only needs one" do
        let(:programmes) { [Programme.flu, Programme.hpv] }

        before do
          create(:vaccination_record, patient:, programme: programmes.first)
          PatientStatusUpdater.call(patient:)
        end

        it "only sends emails for the remaining programme" do
          expect { send_clinic_invitation }.to deliver_email(
            :clinic_initial_invitation
          ).with(
            parent: parents.first,
            patient:,
            programme_types: [programmes.second.type],
            team:,
            academic_year:,
            sent_by:
          )
        end

        it "enqueues a text per parent" do
          expect { send_clinic_invitation }.to deliver_sms(
            :clinic_initial_invitation
          ).with(
            parent: parents.first,
            patient:,
            programme_types: [programmes.second.type],
            team:,
            academic_year:,
            sent_by:
          )
        end
      end

      context "when the team is Coventry & Warwickshire Partnership NHS Trust (CWPT)" do
        let(:team) { create(:team, ods_code: "RYG", programmes:) }

        it "enqueues an email using the CWPT-specific template" do
          expect { send_clinic_invitation }.to deliver_email(
            :clinic_initial_invitation_ryg
          ).with(
            parent: parents.first,
            patient:,
            programme_types:,
            team:,
            academic_year:,
            sent_by:
          )
        end

        it "enqueues an SMS using the CWPT-specific template" do
          expect { send_clinic_invitation }.to deliver_sms(
            :clinic_initial_invitation_ryg
          ).with(
            parent: parents.first,
            patient:,
            programme_types:,
            team:,
            academic_year:,
            sent_by:
          )
        end
      end

      context "when the team is Leicestershire Partnership Trust (LPT)" do
        let(:team) { create(:team, ods_code: "RT5", programmes:) }

        it "enqueues an email using the LPT-specific template" do
          expect { send_clinic_invitation }.to deliver_email(
            :clinic_initial_invitation_rt5
          ).with(
            parent: parents.first,
            patient:,
            programme_types:,
            team:,
            academic_year:,
            sent_by:
          )
        end

        it "enqueues an SMS using the LPT-specific template" do
          expect { send_clinic_invitation }.to deliver_sms(
            :clinic_initial_invitation_rt5
          ).with(
            parent: parents.first,
            patient:,
            programme_types:,
            team:,
            academic_year:,
            sent_by:
          )
        end
      end

      context "when parent doesn't want to receive updates by text" do
        let(:parent) { parents.first }

        before { parent.update!(phone_receive_updates: false) }

        it "still enqueues a text" do
          expect { send_clinic_invitation }.to deliver_sms(
            :clinic_initial_invitation
          ).with(
            parent:,
            patient:,
            programme_types:,
            team:,
            academic_year:,
            sent_by:
          )
        end
      end
    end

    context "when already invited" do
      before do
        create(
          :clinic_notification,
          :initial_invitation,
          patient:,
          team:,
          academic_year:,
          programmes:
        )
      end

      it "creates a record" do
        expect { send_clinic_invitation }.to change(
          ClinicNotification,
          :count
        ).by(1)

        clinic_notification = ClinicNotification.last
        expect(clinic_notification).to be_subsequent_invitation
        expect(clinic_notification.team).to eq(team)
        expect(clinic_notification.patient).to eq(patient)
        expect(clinic_notification.sent_at).to eq(today)
      end

      it "enqueues an email per parent" do
        expect { send_clinic_invitation }.to deliver_email(
          :clinic_subsequent_invitation
        ).with(
          parent: parents.first,
          patient:,
          programme_types:,
          team:,
          academic_year:,
          sent_by:
        ).and deliver_email(:clinic_subsequent_invitation).with(
                parent: parents.second,
                patient:,
                programme_types:,
                team:,
                academic_year:,
                sent_by:
              )
      end

      it "enqueues a text per parent" do
        expect { send_clinic_invitation }.to deliver_sms(
          :clinic_subsequent_invitation
        ).with(
          parent: parents.first,
          patient:,
          programme_types:,
          team:,
          academic_year:,
          sent_by:
        ).and deliver_sms(:clinic_subsequent_invitation).with(
                parent: parents.second,
                patient:,
                programme_types:,
                team:,
                academic_year:,
                sent_by:
              )
      end

      context "when parent doesn't want to receive updates by text" do
        let(:parent) { parents.first }

        before { parent.update!(phone_receive_updates: false) }

        it "still enqueues a text" do
          expect { send_clinic_invitation }.to deliver_sms(
            :clinic_subsequent_invitation
          ).with(
            parent:,
            patient:,
            programme_types:,
            team:,
            academic_year:,
            sent_by:
          )
        end
      end
    end

    context "when already invited to one of two possible programmes" do
      let(:programmes) { [Programme.flu, Programme.hpv] }

      before do
        create(
          :clinic_notification,
          :initial_invitation,
          patient:,
          team:,
          academic_year:,
          programmes: [Programme.flu]
        )
      end

      it "creates a record" do
        expect { send_clinic_invitation }.to change(
          ClinicNotification,
          :count
        ).by(1)

        clinic_notification = ClinicNotification.last
        expect(clinic_notification).to be_initial_invitation
        expect(clinic_notification.team).to eq(team)
        expect(clinic_notification.patient).to eq(patient)
        expect(clinic_notification.sent_at).to eq(today)
      end

      it "enqueues an email per parent" do
        expect { send_clinic_invitation }.to deliver_email(
          :clinic_initial_invitation
        ).with(
          parent: parents.first,
          patient:,
          programme_types:,
          team:,
          academic_year:,
          sent_by:
        ).and deliver_email(:clinic_initial_invitation).with(
                parent: parents.second,
                patient:,
                programme_types:,
                team:,
                academic_year:,
                sent_by:
              )
      end

      it "enqueues a text per parent" do
        expect { send_clinic_invitation }.to deliver_sms(
          :clinic_initial_invitation
        ).with(
          parent: parents.first,
          patient:,
          programme_types:,
          team:,
          academic_year:,
          sent_by:
        ).and deliver_sms(:clinic_initial_invitation).with(
                parent: parents.second,
                patient:,
                programme_types:,
                team:,
                academic_year:,
                sent_by:
              )
      end

      context "when parent doesn't want to receive updates by text" do
        let(:parent) { parents.first }

        before { parent.update!(phone_receive_updates: false) }

        it "still enqueues a text" do
          expect { send_clinic_invitation }.to deliver_sms(
            :clinic_initial_invitation
          ).with(
            parent:,
            patient:,
            programme_types:,
            team:,
            academic_year:,
            sent_by:
          )
        end
      end

      context "and not including already invited programmes" do
        let(:include_already_invited_programmes) { false }

        it "creates a record" do
          expect { send_clinic_invitation }.to change(
            ClinicNotification,
            :count
          ).by(1)

          clinic_notification = ClinicNotification.last
          expect(clinic_notification).to be_initial_invitation
          expect(clinic_notification.team).to eq(team)
          expect(clinic_notification.patient).to eq(patient)
          expect(clinic_notification.sent_at).to eq(today)
          expect(clinic_notification.programmes).to contain_exactly(
            Programme.hpv
          )
        end

        it "enqueues an email per parent" do
          expect { send_clinic_invitation }.to deliver_email(
            :clinic_initial_invitation
          ).with(
            parent: parents.first,
            patient:,
            programme_types: %w[hpv],
            team:,
            academic_year:,
            sent_by:
          ).and deliver_email(:clinic_initial_invitation).with(
                  parent: parents.second,
                  patient:,
                  programme_types: %w[hpv],
                  team:,
                  academic_year:,
                  sent_by:
                )
        end

        it "enqueues a text per parent" do
          expect { send_clinic_invitation }.to deliver_sms(
            :clinic_initial_invitation
          ).with(
            parent: parents.first,
            patient:,
            programme_types: %w[hpv],
            team:,
            academic_year:,
            sent_by:
          ).and deliver_sms(:clinic_initial_invitation).with(
                  parent: parents.second,
                  patient:,
                  programme_types: %w[hpv],
                  team:,
                  academic_year:,
                  sent_by:
                )
        end
      end
    end
  end
end
