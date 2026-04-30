# frozen_string_literal: true

describe AppCreateNoteComponent do
  subject(:rendered) { render_inline(component) }

  let(:patient) { create(:patient) }

  context "for a patient-level note" do
    let(:component) { described_class.new(Note.new(patient:)) }

    it { expect(rendered).to have_css(".nhsuk-details.nhsuk-expander") }

    it do
      expect(rendered).to have_css(
        ".nhsuk-details__summary",
        text: "Add a note to this record"
      )
    end
  end

  context "for a session note" do
    let(:session) { create(:session) }
    let(:component) { described_class.new(Note.new(patient:, session:)) }

    it do
      expect(rendered).to have_css(
        ".nhsuk-details__summary",
        text: "Add a session note"
      )
    end
  end
end
