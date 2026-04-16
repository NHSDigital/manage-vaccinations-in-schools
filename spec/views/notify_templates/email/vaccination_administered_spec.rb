# frozen_string_literal: true

describe "Notify email templates: vaccination_administered", type: :view do
  subject(:rendered) { render_template(vaccination_record:) }

  around { |example| travel_to(Time.zone.local(2024, 10, 1)) { example.run } }

  let(:template_name) { nil }
  let(:programme) { nil }

  let(:team) { create(:team, :with_one_nurse, programmes: [programme]) }
  let(:location) { create(:gias_school, team:, programmes: [programme]) }
  let(:session) do
    create(
      :session,
      team:,
      programmes: [programme],
      location:,
      date: Date.current
    )
  end

  def render_template(vaccination_record:)
    personalisation = GovukNotifyPersonalisation.new(vaccination_record:)

    NotifyTemplate.find(template_name, channel: :email).render(personalisation)
  end

  describe "body" do
    context "flu" do
      let(:template_name) { :vaccination_administered }
      let(:programme) { Programme.flu }

      context "when the vaccination record is injection" do
        let(:vaccine) { programme.vaccines.find_by!(method: "injection") }

        let(:vaccination_record) do
          create(:vaccination_record, programme:, session:, vaccine:)
        end

        it "includes Method: injection" do
          expect(rendered[:body]).to include("Method: injection")
          expect(rendered[:body]).not_to include("nasal spray")
        end
      end

      context "when the vaccination record is nasal" do
        let(:vaccine) { programme.vaccines.find_by!(method: "nasal") }

        let(:vaccination_record) do
          create(:vaccination_record, programme:, session:, vaccine:)
        end

        it "includes Method: nasal spray" do
          expect(rendered[:body]).to include("Method: nasal spray")
          expect(rendered[:body]).not_to include("Method: injection")
        end
      end
    end
  end
end
