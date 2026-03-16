# frozen_string_literal: true

describe AppPatientSessionRecordComponent do
  subject { render_inline(component) }

  let(:component) do
    described_class.new(
      patient:,
      session:,
      programme: programmes.first,
      current_user:,
      vaccinate_form: VaccinateForm.new
    )
  end

  let(:current_user) { create(:user) }
  let(:programmes) { [Programme.hpv] }
  let(:session) { create(:session, :today, programmes:) }
  let(:patient) do
    create(:patient, :consent_given_triage_not_needed, :in_attendance, session:)
  end

  describe "#render?" do
    subject { component.render? }

    it { should be(true) }

    context "patient is not ready for vaccination" do
      let(:patient) { create(:patient, programmes:) }

      it { should be(false) }
    end

    context "patient is not attending the session" do
      let(:patient) do
        create(:patient, :consent_given_triage_not_needed, session:)
      end

      it { should be(false) }
    end

    context "patient attended the session yesterday but not marked as attending today" do
      let(:session) do
        create(:session, programmes:, dates: [Date.yesterday, Date.current])
      end

      let(:patient) do
        create(:patient, :consent_given_triage_not_needed, session:)
      end

      before do
        create(
          :attendance_record,
          patient:,
          location: session.location,
          date: Date.yesterday,
          attending: true
        )

        create(:patient_registration_status, :completed, patient:, session:)
      end

      it { should be(false) }
    end

    context "patient is fully vaccinated" do
      let(:patient) { create(:patient, :vaccinated, programmes:) }

      before do
        create(:patient_registration_status, :completed, patient:, session:)
      end

      it { should be(false) }

      context "but the session was yesterday" do
        let(:session) { create(:session, :yesterday, programmes:) }

        it { should be(false) }
      end
    end

    context "session requires no registration" do
      let(:session) { create(:session, :requires_no_registration, programmes:) }

      it { should be(true) }

      context "but the session was yesterday" do
        let(:session) { create(:session, :yesterday, programmes:) }

        it { should be(false) }
      end
    end
  end
end
