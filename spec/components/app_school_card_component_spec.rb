# frozen_string_literal: true

describe AppSchoolCardComponent do
  subject(:rendered) { render_inline(component) }

  let(:component) { described_class.new(school) }

  let(:programme) { Programme.flu }

  let(:school) do
    create(
      :gias_school,
      :secondary,
      name: "Streeling University",
      urn: "123456",
      address_line_1: "10 Downing Street",
      address_line_2: "Example Way",
      address_postcode: "SW1A 1AA",
      address_town: "London",
      gias_year_groups: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11],
      programmes: [programme]
    )
  end

  it { should have_heading("School details") }

  it { should have_text("ProgrammesFlu") }
  it { should have_text("Year groupsReception and years 1 to 11") }

  it { should have_content("Name") }
  it { should have_content("SW1A 1AA") }

  it { should have_content("URN") }
  it { should have_content("123456") }

  it { should have_content("Phase") }
  it { should have_content("Secondary") }

  it { should have_content("Address") }
  it { should have_content("10 Downing Street, Example Way, London, SW1A 1AA") }
end
