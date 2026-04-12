# frozen_string_literal: true

describe AppPatientSessionRegistrationComponent do
  subject(:rendered) { render_inline(component) }

  let(:component) { described_class.new(patient:, session:) }
  let(:programme) { Programme.flu }
  let(:session) { create(:session, :today, programmes: [programme]) }
  let(:patient) { create(:patient, session:) }

  before { stub_authorization(allowed: true) }

  context "when the session does not require registration" do
    let(:session) do
      create(
        :session,
        :today,
        :requires_no_registration,
        programmes: [programme]
      )
    end

    it "does not render" do
      expect(component.render?).to be false
    end
  end

  context "when the session is not active today" do
    let(:session) { create(:session, :scheduled, programmes: [programme]) }

    it "does not render" do
      expect(component.render?).to be false
    end
  end

  context "when the child has not been registered yet" do
    it { should have_heading("Register attendance") }
    it { should have_css("form") }
    it { should have_text("Yes, they are attending today's session") }
    it { should have_text("No, they are absent from today's session") }
    it { should have_button("Update attendance") }
    it { should_not have_link("Update attendance") }

    context "when the user cannot edit" do
      before { stub_authorization(allowed: false) }

      it { should have_text(patient.full_name) }
      it { should_not have_css("form") }
    end
  end

  context "when the child is attending" do
    before do
      create(:patient_registration_status, :attending, patient:, session:)
    end

    it { should have_heading("Register attendance") }

    it do
      expect(rendered).to have_text(
        "#{patient.full_name} is attending today’s session."
      )
    end

    it { should have_link("Update attendance") }
    it { should_not have_css("form") }

    context "when the user cannot edit" do
      before { stub_authorization(allowed: false) }

      it do
        expect(rendered).to have_text(
          "#{patient.full_name} is attending today’s session."
        )
      end

      it { should_not have_link("Update attendance") }
    end
  end

  context "when the child is absent" do
    before do
      create(:patient_registration_status, :not_attending, patient:, session:)
    end

    it do
      expect(rendered).to have_text(
        "#{patient.full_name} is absent from today’s session."
      )
    end

    it { should have_link("Update attendance") }
    it { should_not have_css("form") }

    context "when the user cannot edit" do
      before { stub_authorization(allowed: false) }

      it do
        expect(rendered).to have_text(
          "#{patient.full_name} is absent from today’s session."
        )
      end

      it { should_not have_link("Update attendance") }
    end
  end

  context "when the child has completed the session" do
    before do
      create(:patient_registration_status, :completed, patient:, session:)
    end

    it { should have_text("#{patient.given_name} has completed this session.") }
    it { should_not have_link("Update registration") }
    it { should_not have_css("form") }
  end
end
