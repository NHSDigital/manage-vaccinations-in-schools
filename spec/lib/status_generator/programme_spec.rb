# frozen_string_literal: true

describe StatusGenerator::Programme do
  subject(:generator) do
    described_class.new(
      programme_type: programme.type,
      academic_year: AcademicYear.current,
      patient:,
      patient_locations:
        patient.patient_locations.includes(
          location: [
            :location_programme_year_groups,
            { team_locations: { sessions: :session_programme_year_groups } }
          ]
        ),
      consents: patient.consents,
      triages: patient.triages,
      attendance_record: patient.attendance_records.first,
      vaccination_records: patient.vaccination_records.order_by_performed_at,
      parents: patient.parents.contactable,
      consent_notifications:
        patient.consent_notifications.includes(session: :team_location),
      notify_log_entries:
        patient.notify_log_entries.includes(:notify_log_entry_programmes)
    )
  end

  let(:programme) { Programme.sample }
  let(:session) do
    create(:session, programmes: [programme], send_consent_requests_at:)
  end
  let(:patient) { create(:patient, session:, parents:) }
  let(:parents) { [create(:parent)] }
  let(:location) { create(:school) }
  let(:send_consent_requests_at) { nil }

  before do
    create(
      :consent_notification,
      :request,
      patient:,
      session:,
      programmes: [programme]
    )
  end

  context "when already vaccinated" do
    let(:programme) { Programme.hpv }

    let!(:vaccination_record) do
      create(:vaccination_record, :already_had, patient:, programme:, location:)
    end

    its(:consent_status) { should be(:not_required) }
    its(:consent_vaccine_methods) { should be_empty }
    its(:date) { should eq(vaccination_record.performed_at.to_date) }
    its(:disease_types) { should eq(%w[human_papillomavirus]) }
    its(:dose_sequence) { should eq(2) }
    its(:location_id) { should eq(location.id) }
    its(:status) { should be(:vaccinated_already) }
    its(:vaccine_methods) { should be_empty }
    its(:without_gelatine) { should be_nil }
  end

  context "when fully vaccinated" do
    let(:programme) { Programme.hpv }

    let!(:vaccination_record) do
      create(:vaccination_record, patient:, programme:, location:)
    end

    its(:consent_status) { should be(:not_required) }
    its(:consent_vaccine_methods) { should be_empty }
    its(:date) { should eq(vaccination_record.performed_at.to_date) }
    its(:disease_types) { should eq(%w[human_papillomavirus]) }
    its(:dose_sequence) { should eq(2) }
    its(:location_id) { should eq(location.id) }
    its(:status) { should be(:vaccinated_fully) }
    its(:vaccine_methods) { should be_empty }
    its(:without_gelatine) { should be_nil }
  end

  context "when partially vaccinated" do
    let(:programme) { Programme.mmr }

    let!(:vaccination_record) do
      create(:vaccination_record, patient:, programme:, location:)
    end

    its(:consent_status) { should be(:no_response) }
    its(:consent_vaccine_methods) { should be_empty }
    its(:date) { should eq(vaccination_record.performed_at.to_date) }
    its(:disease_types) { should be_nil }
    its(:dose_sequence) { should eq(2) }
    its(:location_id) { should be_nil }
    its(:status) { should be(:needs_consent_no_response) }
    its(:vaccine_methods) { should be_nil }
    its(:without_gelatine) { should be_nil }

    context "with consent for the next dose" do
      before { create(:consent, :given, patient:, programme:) }

      its(:consent_status) { should be(:given) }
      its(:consent_vaccine_methods) { should contain_exactly("injection") }
      its(:status) { should be(:due) }
      its(:date) { should eq(vaccination_record.performed_at.to_date) }
      its(:disease_types) { should be_empty }
      its(:vaccine_methods) { should contain_exactly("injection") }
      its(:without_gelatine) { should be(false) }

      context "with a triage delay" do
        before do
          create(
            :triage,
            :delay_vaccination,
            patient:,
            programme:,
            delay_vaccination_until: Date.tomorrow
          )
        end

        its(:status) { should be(:cannot_vaccinate_delay_vaccination) }
      end
    end

    context "without consent for the next dose" do
      its(:consent_status) { should be(:no_response) }
      its(:status) { should be(:needs_consent_no_response) }

      context "with a triage delay" do
        before do
          create(
            :triage,
            :delay_vaccination,
            patient:,
            programme:,
            delay_vaccination_until: Date.tomorrow
          )
        end

        its(:status) { should be(:needs_consent_no_response) }
      end
    end
  end

  context "when the child is unwell" do
    before { create(:consent, :given, patient:, programme:) }

    let!(:vaccination_record) do
      create(:vaccination_record, :unwell, patient:, programme:, location:)
    end

    its(:consent_status) { should be(:given) }
    its(:consent_vaccine_methods) { should contain_exactly("injection") }
    its(:date) { should eq(vaccination_record.performed_at.to_date) }
    its(:disease_types) { should eq(programme.disease_types) }
    its(:location_id) { should be_nil }
    its(:status) { should be(:cannot_vaccinate_unwell) }
    its(:vaccine_methods) { should contain_exactly("injection") }
    its(:without_gelatine) { should be(false) }

    context "on a different day" do
      let!(:vaccination_record) do
        create(
          :vaccination_record,
          :unwell,
          :yesterday,
          patient:,
          programme:,
          location:
        )
      end

      its(:date) { should eq(vaccination_record.performed_at.to_date) }
      its(:location_id) { should be_nil }
      its(:status) { should be(:due) }
    end
  end

  context "when the child refused" do
    before { create(:consent, :given, patient:, programme:) }

    let!(:vaccination_record) do
      create(:vaccination_record, :refused, patient:, programme:, location:)
    end

    its(:consent_status) { should be(:given) }
    its(:consent_vaccine_methods) { should contain_exactly("injection") }
    its(:date) { should eq(vaccination_record.performed_at.to_date) }
    its(:disease_types) { should eq(programme.disease_types) }
    its(:location_id) { should be_nil }
    its(:status) { should be(:cannot_vaccinate_refused) }
    its(:vaccine_methods) { should contain_exactly("injection") }
    its(:without_gelatine) { should be(false) }

    context "on a different day" do
      let!(:vaccination_record) do
        create(:vaccination_record, :unwell, :yesterday, patient:, programme:)
      end

      its(:date) { should eq(vaccination_record.performed_at.to_date) }
      its(:location_id) { should be_nil }
      its(:status) { should be(:due) }
    end
  end

  context "when contraindicated" do
    before { create(:consent, :given, patient:, programme:) }

    let!(:vaccination_record) do
      create(
        :vaccination_record,
        :contraindicated,
        patient:,
        programme:,
        location:
      )
    end

    its(:consent_status) { should be(:given) }
    its(:consent_vaccine_methods) { should contain_exactly("injection") }
    its(:date) { should eq(vaccination_record.performed_at.to_date) }
    its(:disease_types) { should eq(programme.disease_types) }
    its(:location_id) { should be_nil }
    its(:status) { should be(:cannot_vaccinate_contraindicated) }
    its(:vaccine_methods) { should contain_exactly("injection") }
    its(:without_gelatine) { should be(false) }

    context "on a different day" do
      let!(:vaccination_record) do
        create(:vaccination_record, :unwell, :yesterday, patient:, programme:)
      end

      its(:date) { should eq(vaccination_record.performed_at.to_date) }
      its(:location_id) { should be_nil }
      its(:status) { should be(:due) }
    end
  end

  context "when the child was marked as absent" do
    before { create(:consent, :given, patient:, programme:) }

    let!(:attendance_record) do
      create(:attendance_record, :absent, patient:, session:)
    end

    its(:consent_status) { should be(:given) }
    its(:consent_vaccine_methods) { should contain_exactly("injection") }
    its(:date) { should eq(attendance_record.date) }
    its(:disease_types) { should eq(programme.disease_types) }
    its(:location_id) { should be_nil }
    its(:status) { should be(:cannot_vaccinate_absent) }
    its(:vaccine_methods) { should contain_exactly("injection") }
    its(:without_gelatine) { should be(false) }

    context "on a different day" do
      let!(:attendance_record) do
        create(:attendance_record, :absent, :yesterday, patient:)
      end

      its(:status) { should be(:due) }
      its(:date) { should eq(attendance_record.date) }
    end
  end

  context "when triaged as delay" do
    let(:programme) { Programme.menacwy }

    before do
      create(:consent, :given, patient:, programme:)
      create(
        :triage,
        :delay_vaccination,
        patient:,
        programme:,
        delay_vaccination_until: Date.tomorrow
      )
    end

    its(:consent_status) { should be(:given) }
    its(:consent_vaccine_methods) { should contain_exactly("injection") }
    its(:date) { should eq(Date.tomorrow) }
    its(:disease_types) { should eq(programme.disease_types) }
    its(:dose_sequence) { should eq(1) }
    its(:location_id) { should be_nil }
    its(:status) { should be(:cannot_vaccinate_delay_vaccination) }
    its(:vaccine_methods) { should contain_exactly("injection") }
    its(:without_gelatine) { should be(false) }
  end

  context "when triaged as invite to clinic" do
    let(:programme) { Programme.hpv }

    before do
      create(:consent, :given, patient:, programme:)
      create(:triage, :invite_to_clinic, patient:, programme:)
    end

    its(:consent_status) { should be(:given) }
    its(:consent_vaccine_methods) { should contain_exactly("injection") }
    its(:date) { should be_nil }
    its(:disease_types) { should eq(programme.disease_types) }
    its(:dose_sequence) { should eq(1) }
    its(:location_id) { should be_nil }
    its(:status) { should be(:needs_triage) }
    its(:vaccine_methods) { should be_nil }
    its(:without_gelatine) { should be_nil }
  end

  context "when triaged as do not vaccinate" do
    let(:programme) { Programme.td_ipv }

    before do
      create(:consent, :given, patient:, programme:)
      create(:triage, :do_not_vaccinate, patient:, programme:)
    end

    its(:consent_status) { should be(:given) }
    its(:consent_vaccine_methods) { should contain_exactly("injection") }
    its(:date) { should be_nil }
    its(:disease_types) { should eq(programme.disease_types) }
    its(:dose_sequence) { should eq(5) }
    its(:location_id) { should be_nil }
    its(:status) { should be(:cannot_vaccinate_do_not_vaccinate) }
    its(:vaccine_methods) { should be_nil }
    its(:without_gelatine) { should be_nil }
  end

  context "when needs triage" do
    let(:programme) { Programme.flu }

    before { create(:consent, :given, :needing_triage, patient:, programme:) }

    its(:consent_status) { should be(:given) }
    its(:consent_vaccine_methods) { should contain_exactly("injection") }
    its(:date) { should be_nil }
    its(:disease_types) { should eq(programme.disease_types) }
    its(:dose_sequence) { should eq(1) }
    its(:location_id) { should be_nil }
    its(:status) { should be(:needs_triage) }
    its(:vaccine_methods) { should be_nil }
    its(:without_gelatine) { should be_nil }
  end

  context "when consent is refused" do
    let(:programme) { Programme.mmr }

    before { create(:consent, :refused, patient:, programme:) }

    its(:consent_status) { should be(:refused) }
    its(:consent_vaccine_methods) { should be_empty }
    its(:date) { should be_nil }
    its(:disease_types) { should be_empty }
    its(:dose_sequence) { should eq(1) }
    its(:location_id) { should be_nil }
    its(:status) { should be(:has_refusal_consent_refused) }
    its(:vaccine_methods) { should be_nil }
    its(:without_gelatine) { should be_nil }
  end

  context "when consent is conflicting" do
    let(:programme) { Programme.mmr }

    before do
      create(:consent, :refused, patient:, programme:)
      create(:consent, :given, patient:, programme:, parent: create(:parent))
    end

    its(:consent_status) { should be(:conflicts) }
    its(:consent_vaccine_methods) { should be_empty }
    its(:date) { should be_nil }
    its(:disease_types) { should be_empty }
    its(:dose_sequence) { should be(1) }
    its(:location_id) { should be_nil }
    its(:status) { should be(:has_refusal_consent_conflicts) }
    its(:vaccine_methods) { should be_nil }
    its(:without_gelatine) { should be_nil }
  end

  context "when consent is needed" do
    let(:programme) { Programme.menacwy }

    its(:consent_status) { should be(:no_response) }
    its(:consent_vaccine_methods) { should be_empty }
    its(:date) { should be_nil }
    its(:disease_types) { should be_nil }
    its(:dose_sequence) { should eq(1) }
    its(:location_id) { should be_nil }
    its(:status) { should be(:needs_consent_no_response) }
    its(:vaccine_methods) { should be_nil }
    its(:without_gelatine) { should be_nil }

    context "when the latest consent request delivery has failed" do
      before do
        create(
          :notify_log_entry,
          :email,
          :permanent_failure,
          :consent_request,
          patient:,
          programme_types: [programme.type]
        )
      end

      its(:status) { should be(:needs_consent_request_failed) }
    end

    context "when a consent request is scheduled for a future session" do
      let(:send_consent_requests_at) { Date.tomorrow }

      before { ConsentNotification.delete_all }

      its(:status) { should be(:needs_consent_request_scheduled) }
    end

    context "when a consent requests are not scheduled to go out in the future" do
      let(:send_consent_requests_at) { nil }

      before { ConsentNotification.delete_all }

      its(:status) { should be(:needs_consent_request_not_scheduled) }
    end

    context "when there is a future session for a different programme" do
      before do
        create(
          :session,
          programmes: [Programme.hpv],
          team_location: session.team_location,
          send_consent_requests_at: Date.tomorrow
        )
      end

      its(:status) { should be(:needs_consent_no_response) }
    end

    context "when there are no contact details for parents and no consent request has been sent" do
      let(:parents) { [create(:parent, :non_contactable)] }

      its(:status) { should be(:needs_consent_no_contact_details) }
    end

    context "when there are no parent relationships and no consent request has been sent" do
      let(:parents) { [] }

      its(:status) { should be(:needs_consent_no_contact_details) }
    end

    context "with a multi-dose programme" do
      let(:programme) { Programme.mmr }

      its(:dose_sequence) { should eq(1) }
    end
  end

  context "when not eligible" do
    let(:patient) { create(:patient, year_group: 20) }

    its(:consent_status) { should be(:no_response) }
    its(:consent_vaccine_methods) { should be_empty }
    its(:date) { should be_nil }
    its(:disease_types) { should be_nil }
    its(:dose_sequence) { should be_nil }
    its(:location_id) { should be_nil }
    its(:status) { should be(:not_eligible) }
    its(:vaccine_methods) { should be_nil }
    its(:without_gelatine) { should be_nil }
  end
end
