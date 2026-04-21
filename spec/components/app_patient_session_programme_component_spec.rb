# frozen_string_literal: true

describe AppPatientSessionProgrammeComponent do
  subject(:rendered) { render_inline(component) }

  let(:component) { described_class.new(patient:, session:, programme:) }

  let(:programme) { Programme.flu }
  let(:session) { create(:session, programmes: [programme]) }
  let(:patient) { create(:patient, session:) }

  it { should have_css("a.nhsuk-action-link", text: "View child’s Flu record") }

  context "when due (nasal)" do
    before do
      create(:patient_programme_status, :due_nasal, patient:, programme:)
    end

    it { should have_css("h4", text: "Flu:") }
    it { should_not have_css("table") }

    it "shows ready to vaccinate details" do
      expect(rendered).to have_text(
        "#{patient.given_name} is ready to vaccinate (nasal spray only)."
      )
    end
  end

  context "when due (injection)" do
    before do
      create(:patient_programme_status, :due_injection, patient:, programme:)
    end

    it "shows ready to vaccinate details without criteria label for flu injection" do
      expect(rendered).to have_text(
        "#{patient.given_name} is ready to vaccinate"
      )
    end
  end

  context "when vaccinated" do
    before do
      create(:patient_programme_status, :vaccinated_fully, patient:, programme:)
    end

    context "with a known nurse" do
      let!(:vaccination_record) do
        create(
          :vaccination_record,
          :performed_by_not_user,
          patient:,
          programme:,
          session:
        )
      end

      it { should have_css("table") }

      it "shows vaccinated by nurse details" do
        nurse = [
          vaccination_record.performed_by_given_name,
          vaccination_record.performed_by_family_name
        ].join(" ")

        expect(rendered).to have_text(
          "#{patient.given_name} was vaccinated by #{nurse} on"
        )
      end
    end

    context "without a known nurse" do
      before do
        create(
          :vaccination_record,
          patient:,
          programme:,
          session:,
          performed_by_given_name: nil,
          performed_by_family_name: nil
        )
        PatientStatusUpdater.call(patient:)
      end

      it { should have_css("table") }

      it "shows vaccinated without nurse details" do
        expect(rendered).to have_text("#{patient.given_name} was vaccinated on")
        expect(rendered).not_to have_text("vaccinated by")
      end
    end
  end

  context "when the child could not be vaccinated" do
    before do
      create(
        :vaccination_record,
        :not_administered,
        patient:,
        programme:,
        session:
      )
      PatientStatusUpdater.call(patient:)
    end

    it { should have_css("table") }

    it "shows child unwell details" do
      expect(rendered).to have_text("Child unwell on")
    end
  end

  context "when needs triage" do
    before do
      create(:patient_programme_status, :needs_triage, patient:, programme:)
    end

    it { should have_css("h4", text: "Flu:") }
    it { should_not have_css("table") }

    it "shows needs triage details" do
      expect(rendered).to have_text(
        "You need to decide if it’s safe to vaccinate #{patient.given_name}."
      )
    end
  end

  context "when triaged" do
    let(:nurse) { create(:user) }

    context "safe to vaccinate" do
      before do
        create(:patient_programme_status, :due_injection, patient:, programme:)
        create(
          :triage,
          :safe_to_vaccinate,
          patient:,
          programme:,
          performed_by: nurse
        )
      end

      it "shows ready to vaccinate details, not triage summary" do
        expect(rendered).to have_text(
          "#{patient.given_name} is ready to vaccinate"
        )
        expect(rendered).not_to have_text("#{nurse.full_name} decided that")
      end
    end

    context "do not vaccinate" do
      before do
        create(
          :patient_programme_status,
          :cannot_vaccinate_do_not_vaccinate,
          patient:,
          programme:
        )
        create(
          :triage,
          :do_not_vaccinate,
          patient:,
          programme:,
          performed_by: nurse
        )
      end

      it "shows triage summary" do
        expect(rendered).to have_text(
          "#{nurse.full_name} decided that #{patient.given_name} should not be vaccinated."
        )
      end
    end

    context "delay vaccination" do
      let!(:triage) do
        create(
          :triage,
          :delay_vaccination,
          patient:,
          programme:,
          performed_by: nurse
        )
      end

      before do
        create(
          :patient_programme_status,
          :cannot_vaccinate_delay_vaccination,
          patient:,
          programme:
        )
      end

      it "shows triage summary with delay date" do
        expect(rendered).to have_text(
          "#{nurse.full_name} decided that #{patient.given_name}’s vaccination should be delayed " \
            "until #{triage.delay_vaccination_until.to_fs(:long)}."
        )
      end
    end

    context "invite to clinic" do
      before do
        create(:patient_programme_status, :needs_triage, patient:, programme:)
        create(
          :triage,
          :invite_to_clinic,
          patient:,
          programme:,
          performed_by: nurse
        )
      end

      it "shows triage summary" do
        expect(rendered).to have_text(
          "#{nurse.full_name} decided that #{patient.given_name}’s vaccination should take place at a clinic."
        )
      end
    end
  end
end
