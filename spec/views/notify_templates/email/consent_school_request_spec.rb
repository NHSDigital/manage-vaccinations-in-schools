# frozen_string_literal: true

describe "Notify email templates: consent school requests", type: :view do
  around { |example| travel_to(Date.new(2024, 1, 1)) { example.run } }

  let(:team) { create(:team, :with_one_nurse, programmes: [programme]) }
  let(:location) { create(:gias_school, team:, programmes: [programme]) }
  let(:parent) { create(:parent) }

  let(:session_dates) { [Date.current + 2.days] }
  let(:patient_year_group) { 8 }

  let(:session) do
    create(
      :session,
      :scheduled,
      team:,
      location:,
      programmes: [programme],
      dates: session_dates
    )
  end

  let(:patient) do
    create(
      :patient,
      session:,
      parents: [parent],
      year_group: patient_year_group
    )
  end

  def render_template(template_name)
    personalisation =
      GovukNotifyPersonalisation.new(
        parent:,
        patient:,
        programme_types: [programme.type],
        session:,
        team:
      )

    NotifyTemplate.find(template_name, channel: :email).render(personalisation)
  end

  shared_examples "a consent school request email" do |template_name:|
    subject(:rendered) { render_template(template_name) }

    it "renders a subject including the child name" do
      expect(rendered[:subject]).to include(patient.given_name)
    end

    context "when the session has one date" do
      it "does not include the multiple-dates caveat" do
        expect(rendered[:body]).not_to include(
          "We cannot say on which of the above dates"
        )
      end
    end

    context "when the session has multiple dates" do
      let(:session_dates) { [Date.current + 2.days, Date.current + 3.days] }

      it "includes the multiple-dates caveat" do
        expect(rendered[:body]).to include(
          "We cannot say on which of the above dates"
        )
      end
    end
  end

  describe "HPV" do
    subject(:rendered) { render_template(:consent_school_request_hpv) }

    let(:programme) { Programme.hpv }

    include_examples(
      "a consent school request email",
      template_name: :consent_school_request_hpv
    )

    context "when the patient is in the routine year group" do
      let(:patient_year_group) { 8 }

      it "includes the routine year group copy and not the catch-up paragraph" do
        expect(rendered[:body]).to include("to pupils in Year 8")
        expect(rendered[:body]).not_to include(
          "Our records show your child has not had their HPV vaccination."
        )
      end
    end

    context "when the patient is in a catch-up year group" do
      let(:patient_year_group) { 9 }

      it "includes the catch-up paragraph and not the routine year group copy" do
        expect(rendered[:body]).not_to include("to pupils in Year 8")
        expect(rendered[:body]).to include(
          "Our records show your child has not had their HPV vaccination."
        )
      end
    end
  end

  describe "Flu" do
    let(:programme) { Programme.flu }

    include_examples(
      "a consent school request email",
      template_name: :consent_school_request_flu
    )
  end

  describe "MMR" do
    let(:programme) { Programme.mmr }

    include_examples(
      "a consent school request email",
      template_name: :consent_school_request_mmr
    )
  end

  describe "Doubles" do
    let(:programme) { Programme.menacwy }

    include_examples(
      "a consent school request email",
      template_name: :consent_school_request_doubles
    )
  end

  describe "MMRV" do
    let(:programme) { Programme.mmr }

    include_examples(
      "a consent school request email",
      template_name: :consent_school_request_mmrv
    )
  end
end
