# frozen_string_literal: true

describe AppPatientSessionHealthAnswersComponent do
  subject(:rendered) { render_inline(component) }

  let(:component) { described_class.new(patient:, session:, programme:) }

  let(:programme) { Programme.hpv }
  let(:session) { create(:session, programmes: [programme]) }
  let(:patient) { create(:patient, session:) }

  context "without any given consent" do
    it { expect(rendered.to_html).to be_blank }
  end

  context "with refused consent" do
    before { create(:consent, :refused, patient:, programme:) }

    it { expect(rendered.to_html).to be_blank }
  end

  context "with given consent, all no health answers" do
    before do
      create(:consent, :given, :no_contraindications, patient:, programme:)
    end

    it { should have_css("section", text: "All answers to health questions") }
    it { should_not have_css(".nhsuk-card--warning") }
    it { should_not have_text("Yes response") }
  end

  context "with given consent with 1 yes health answer" do
    before do
      create(:consent, :given, :health_question_notes, patient:, programme:)
    end

    it { should have_css(".nhsuk-card--warning") }
    it { should have_text("including 1 Yes response") }
  end

  context "with given consent with multiple yes health answers" do
    before do
      create(
        :consent,
        :given,
        patient:,
        programme:,
        health_answers: [
          HealthAnswer.new(question: "Question 1", response: "yes"),
          HealthAnswer.new(question: "Question 2", response: "yes"),
          HealthAnswer.new(question: "Question 3", response: "no")
        ]
      )
    end

    it { should have_css(".nhsuk-card--warning") }
    it { should have_text("including 2 Yes responses") }
  end
end
