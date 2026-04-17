# frozen_string_literal: true

describe "Downloads index" do
  let(:team) { create(:team, :with_one_nurse) }
  let(:user) { team.users.first }

  before { sign_in user }

  it "shows the page" do
    visit downloads_path
    expect(page).to have_content("Downloads")
  end

  it "shows an empty list when no exports exist" do
    visit downloads_path
    within(".app-grid-column-results") do
      expect(page).not_to have_css(".nhsuk-card")
    end
  end
end
