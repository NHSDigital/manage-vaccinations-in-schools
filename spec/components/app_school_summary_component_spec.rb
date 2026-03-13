# frozen_string_literal: true

describe AppSchoolSummaryComponent do
  subject(:rendered) { render_inline(component) }

  let(:component) { described_class.new(school, change_links:) }

  let(:programmes) { [Programme.hpv] }
  let(:team) { create(:team, :with_one_nurse, programmes:) }
  let(:current_user) { team.users.first }
  let(:academic_year) { AcademicYear.pending }
  let(:school) do
    create(
      :school,
      :secondary,
      name: "Streeling University",
      urn: "123456",
      address_line_1: "10 Downing Street",
      address_line_2: "Example Way",
      address_postcode: "SW1A 1AA",
      address_town: "London",
      gias_year_groups: [7, 8, 9, 10, 11],
      programmes:,
      team:,
      academic_year:
    )
  end
  let(:change_links) { {} }

  it { should have_content("ProgrammesHPV") }
  it { should have_content("Year groupsYears 7 to 11") }

  it { should have_content("Name") }
  it { should have_content("SW1A 1AA") }

  it { should have_content("URN") }
  it { should have_content("123456") }

  it { should have_content("Phase") }
  it { should have_content("Secondary") }

  it { should have_content("Address") }
  it { should have_content("10 Downing Street, Example Way, London, SW1A 1AA") }

  context "when there are change links" do
    let(:change_links) do
      {
        name: {
          link: "/name",
          text: "Change name"
        },
        address: {
          link: "/address",
          text: "Change address"
        },
        year_groups: {
          link: "/year-groups"
        }
      }
    end
    let(:component) { described_class.new(school, change_links:) }

    it { should have_link("Change name", href: "/name") }
    it { should have_link("Change address", href: "/address") }
    it { should have_link("Change year groups", href: "/year-groups") }
  end

  context "when schoolable is a DraftSchool (adding a new site)" do
    let(:draft_school) do
      DraftSchool.new(
        request_session: {
        },
        current_user:,
        name: "Edited School Name",
        address_line_1: "20 Downing Street",
        address_line_2: "New Way",
        address_town: "London",
        address_postcode: "SW1A 2AA",
        parent_urn_and_site: school.urn_and_site
      )
    end
    let(:component) { described_class.new(draft_school, change_links:) }

    it { should have_content("URN") }
    it { should have_content("123456") }

    it { should have_content("Name") }
    it { should have_content("Edited School Name") }

    it { should have_content("Address") }
    it { should have_content("20 Downing Street, New Way, London, SW1A 2AA") }

    it "shows phase from the underlying location" do
      expect(rendered).to have_content("Phase")
      expect(rendered).to have_content("Secondary")
    end

    it "shows programmes from the underlying location" do
      expect(rendered).to have_content("Programmes")
      expect(rendered).to have_content("HPV")
    end

    it "shows year groups from the underlying location" do
      expect(rendered).to have_content("Year groups")
      expect(rendered).to have_content("Years 7 to 11")
    end

    context "with change links" do
      let(:change_links) { { urn: { link: "/urn" } } }

      it { should have_link("Change", href: "/urn") }
    end
  end

  context "when schoolable is a DraftSchool (editing an existing school)" do
    let(:draft_school) do
      DraftSchool.new(
        request_session: {
        },
        current_user:,
        name: "Edited School Name",
        address_line_1: "20 Downing Street",
        address_line_2: "New Way",
        address_town: "London",
        address_postcode: "SW1A 2AA",
        editing_id: school.id
      )
    end
    let(:component) { described_class.new(draft_school, change_links:) }

    it { should have_content("URN") }
    it { should have_content("123456") }

    it { should have_content("Name") }
    it { should have_content("Edited School Name") }

    it { should have_content("Address") }
    it { should have_content("20 Downing Street, New Way, London, SW1A 2AA") }

    it "shows phase from the underlying location" do
      expect(rendered).to have_content("Phase")
      expect(rendered).to have_content("Secondary")
    end

    it "shows programmes from the underlying location" do
      expect(rendered).to have_content("Programmes")
      expect(rendered).to have_content("HPV")
    end

    it "shows year groups from the underlying location" do
      expect(rendered).to have_content("Year groups")
      expect(rendered).to have_content("Years 7 to 11")
    end
  end
end
