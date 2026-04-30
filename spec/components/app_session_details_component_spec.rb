# frozen_string_literal: true

describe AppSessionDetailsComponent do
  subject(:rendered) { render_inline(component) }

  let(:component) { described_class.new(session) }
  let(:programme) { Programme.flu }
  let(:team) { create(:team, programmes: [programme]) }
  let(:location) { create(:generic_clinic, team:, programmes: [programme]) }
  let(:session) do
    create(:session, :scheduled, team:, location:, programmes: [programme])
  end

  before do
    stub_authorization(
      klass: SessionPolicy,
      permissions: {
        edit?: true,
        cancel?: true
      }
    )
  end

  it "shows the edit and cancel actions" do
    expect(rendered).to have_link("Edit session")
    expect(rendered).to have_link("Cancel session")
  end

  context "when cancelling is not allowed" do
    before do
      stub_authorization(
        klass: SessionPolicy,
        permissions: {
          edit?: true,
          cancel?: false
        }
      )
    end

    it "does not show cancel action" do
      expect(rendered).to have_link("Edit session")
      expect(rendered).not_to have_link("Cancel session")
    end
  end
end
