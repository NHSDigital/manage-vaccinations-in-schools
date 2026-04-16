# frozen_string_literal: true

describe "Notify email templates: triage_vaccination_will_happen_mmr_second_dose",
         type: :view do
  subject(:rendered) { render_template }

  let(:programme) { Programme.mmr }
  let(:team) { create(:team, :with_one_nurse, programmes: [programme]) }
  let(:session) do
    create(
      :session,
      team:,
      programmes: [programme],
      date: Date.new(2025, 6, 10)
    )
  end
  let(:patient) do
    create(
      :patient,
      :partially_vaccinated_triage_needed,
      given_name: "Filip",
      date_of_birth: Date.new(2015, 6, 1),
      session:
    )
  end
  let(:consent) { patient.consents.first }

  def render_template
    PatientStatusUpdater.call(patient:)
    patient.programme_statuses.reload
    personalisation = GovukNotifyPersonalisation.new(consent:, session:)
    NotifyTemplate.find(
      :triage_vaccination_will_happen_mmr_second_dose,
      channel: :email
    ).render(personalisation)
  end

  context "with an MMR programme" do
    it "includes the programme name in the subject" do
      expect(rendered[:subject]).to include("MMR vaccination")
    end

    it "describes the first dose given" do
      expect(rendered[:body]).to include(
        "We recently gave Filip their 1st dose of the MMR vaccination"
      )
    end

    it "describes the next dose" do
      expect(rendered[:body]).to include(
        "plan to give Filip their 2nd dose then"
      )
    end
  end

  context "with an MMRV programme" do
    let(:patient) do
      create(
        :patient,
        :partially_vaccinated_triage_needed,
        given_name: "Filip",
        date_of_birth: Date.new(2020, 6, 1),
        session:
      )
    end

    it "includes the programme name in the subject" do
      expect(rendered[:subject]).to include("MMRV vaccination")
    end

    it "describes the first dose given" do
      expect(rendered[:body]).to include(
        "We recently gave Filip their 1st dose of the MMRV vaccination"
      )
    end

    it "describes the next dose" do
      expect(rendered[:body]).to include(
        "plan to give Filip their 2nd dose then"
      )
    end
  end
end
