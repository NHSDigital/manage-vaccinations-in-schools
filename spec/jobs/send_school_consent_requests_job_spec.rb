# frozen_string_literal: true

describe SendSchoolConsentRequestsJob do
  subject(:perform_now) { described_class.perform_now(session) }

  let(:today) { Date.new(2025, 7, 1) }
  let(:programmes) { [Programme.sample] }
  let(:parents) { create_list(:parent, 2) }
  let(:patient_with_request_sent) do
    create(:patient, :consent_no_response, :consent_request_sent, programmes:)
  end
  let(:patient_with_request_sent_last_year) do
    previous_session =
      create(
        :session,
        :unscheduled,
        programmes:,
        academic_year: AcademicYear.previous
      )
    create(
      :patient,
      :consent_no_response,
      :consent_request_sent,
      year_group: 8,
      parents:,
      programmes:,
      session: previous_session
    ).tap do |patient|
      programmes.each do |programme|
        create(
          :patient_programme_status,
          :needs_consent_no_response,
          patient:,
          programme:
        )
      end
    end
  end
  let(:patient_not_sent_request) do
    create(:patient, :consent_no_response, parents:, programmes:)
  end
  let(:patient_with_consent) do
    create(:patient, :consent_given_triage_not_needed, programmes:)
  end
  let(:deceased_patient) { create(:patient, :deceased) }
  let(:invalid_patient) { create(:patient, :invalidated) }
  let(:restricted_patient) { create(:patient, :restricted) }
  let!(:patients) do
    [
      patient_with_request_sent,
      patient_with_request_sent_last_year,
      patient_not_sent_request,
      patient_with_consent,
      deceased_patient,
      invalid_patient,
      restricted_patient
    ]
  end

  before do
    patients.each { |patient| create(:patient_location, patient:, session:) }
  end

  around { |example| travel_to(today) { example.run } }

  context "when session is unscheduled" do
    let(:session) { create(:session, :unscheduled, programmes:) }

    it "doesn't send any notifications" do
      expect { perform_now }.not_to change(ConsentNotification, :count)
    end
  end

  context "when session is scheduled" do
    let(:session) do
      create(
        :session,
        programmes:,
        date: 3.weeks.from_now.to_date,
        send_consent_requests_at: Date.current
      )
    end

    it "sends notifications to expected patients" do
      expect { perform_now }.to change(ConsentNotification, :count).by(2)
      expect(
        ConsentNotification.order(:sent_at).last(2).map(&:patient_id)
      ).to contain_exactly(
        patient_not_sent_request.id,
        patient_with_request_sent_last_year.id
      )
    end

    context "with Td/IPV and MenACWY" do
      let(:programmes) { [Programme.menacwy, Programme.td_ipv] }

      it "sends one notification to one patient" do
        expect { perform_now }.to change(ConsentNotification, :count).by(2)
        expect(
          ConsentNotification.order(:sent_at).last(2).map(&:patient_id)
        ).to contain_exactly(
          patient_not_sent_request.id,
          patient_with_request_sent_last_year.id
        )
      end
    end

    context "with HPV, Td/IPV and MenACWY" do
      let(:hpv_programme) { Programme.hpv }
      let(:menacwy_programme) { Programme.menacwy }
      let(:td_ipv_programme) { Programme.td_ipv }

      let(:programmes) { [hpv_programme, menacwy_programme, td_ipv_programme] }

      context "when the patient is in Year 8" do
        let(:patient_not_sent_request) do
          create(:patient, year_group: 8, parents:, programmes:)
        end

        before { PatientStatusUpdater.call(patient: patient_not_sent_request) }

        it "sends only notifications for HPV" do
          expect { perform_now }.to change(ConsentNotification, :count).by(3)
          expect(
            ConsentNotification.find_by!(
              patient: patient_not_sent_request
            ).programmes
          ).to contain_exactly(hpv_programme)
        end
      end

      context "when the patient is in Year 9" do
        let(:patient_not_sent_request) do
          create(:patient, year_group: 9, parents:, programmes:)
        end

        before { PatientStatusUpdater.call(patient: patient_not_sent_request) }

        it "sends notifications for HPV, and MenACWY and Td/IPV separately" do
          expect { perform_now }.to change(ConsentNotification, :count).by(4)
          expect(
            ConsentNotification.where(patient: patient_not_sent_request).map(
              &:programme_types
            )
          ).to contain_exactly(%w[hpv], %w[menacwy td_ipv])
        end
      end
    end

    context "when location is a generic clinic" do
      let(:team) { create(:team, programmes:) }
      let(:location) { create(:generic_clinic, team:) }
      let(:session) { create(:session, programmes:, team:) }

      it "doesn't send any notifications" do
        expect { perform_now }.not_to change(ConsentNotification, :count)
      end
    end
  end
end
