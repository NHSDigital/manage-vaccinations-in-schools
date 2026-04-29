# frozen_string_literal: true

describe DraftSchool do
  subject(:draft_school) do
    described_class.new(
      request_session:,
      current_user:,
      current_team: team,
      **attributes
    )
  end

  let(:team) { create(:team, :with_one_nurse) }
  let(:current_user) { team.users.first }
  let(:request_session) { {} }

  let(:school) { create(:gias_school, :secondary, team:) }

  let(:valid_attributes) do
    {
      context: "add_site",
      parent_urn_and_site: school.urn_and_site,
      name: "New Site Name",
      address_line_1: "123 Main Street",
      address_line_2: "Floor 2",
      address_town: "London",
      address_postcode: "SW1A 1AA"
    }
  end

  describe "validations" do
    context "on the school step" do
      let(:attributes) { { wizard_step: :school, context: "add_site" } }

      it { should validate_presence_of(:parent_urn_and_site).on(:update) }

      context "with valid urn_and_site" do
        let(:attributes) do
          {
            wizard_step: :school,
            context: "add_site",
            parent_urn_and_site: school.urn_and_site
          }
        end

        it { should be_valid(:update) }
      end
    end

    context "on the details step" do
      let(:attributes) { valid_attributes.merge(wizard_step: :details) }

      it { should validate_presence_of(:name).on(:update) }
      it { should validate_presence_of(:address_line_1).on(:update) }
      it { should validate_presence_of(:address_town).on(:update) }
      it { should validate_presence_of(:address_postcode).on(:update) }

      context "with valid attributes" do
        it { should be_valid(:update) }
      end

      context "with a duplicate name" do
        let(:attributes) do
          valid_attributes.merge(wizard_step: :details, name: school.name)
        end

        it "is invalid" do
          expect(draft_school).not_to be_valid(:update)
          expect(draft_school.errors[:name]).to include(
            "This site name is already in use. Enter a different name."
          )
        end
      end

      context "with an invalid postcode" do
        let(:attributes) do
          valid_attributes.merge(
            wizard_step: :details,
            address_postcode: "invalid"
          )
        end

        it { should_not be_valid(:update) }
      end

      context "without address_line_2" do
        let(:attributes) do
          valid_attributes.merge(wizard_step: :details, address_line_2: nil)
        end

        it { should be_valid(:update) }
      end

      context "with invalid characters in name" do
        let(:attributes) do
          valid_attributes.merge(wizard_step: :details, name: "School with []")
        end

        it "is invalid" do
          expect(draft_school).not_to be_valid(:update)
          expect(draft_school.errors[:name]).to include(
            "includes invalid character(s)"
          )
        end
      end

      context "with valid special characters in name" do
        [
          "St Mary's & St John's",
          "École Française",
          "Smith-Jones School",
          "St. Mary's School, (Site A)"
        ].each do |valid_name|
          context "with name '#{valid_name}'" do
            let(:attributes) do
              valid_attributes.merge(wizard_step: :details, name: valid_name)
            end

            it { should be_valid(:update) }
          end
        end
      end
    end

    context "on the year_groups step" do
      context "without any year groups selected" do
        let(:attributes) do
          valid_attributes.merge(
            wizard_step: :year_groups,
            selected_year_groups: []
          )
        end

        it "is invalid" do
          expect(draft_school).not_to be_valid(:update)
          expect(draft_school.errors[:selected_year_groups]).to include(
            "Choose which year groups are in this school"
          )
        end
      end

      context "with year groups selected" do
        let(:attributes) do
          valid_attributes.merge(
            wizard_step: :year_groups,
            selected_year_groups: [8, 9]
          )
        end

        it { should be_valid(:update) }
      end

      context "when editing and removing existing year groups" do
        let(:existing_site) do
          create(
            :gias_school,
            urn: school.urn,
            site: "A",
            gias_year_groups: [8, 9, 10]
          )
        end
        let(:attributes) do
          {
            editing_id: existing_site.id,
            wizard_step: :year_groups,
            selected_year_groups: [8]
          }
        end

        it "is invalid" do
          expect(draft_school).not_to be_valid(:update)
          expect(draft_school.errors[:selected_year_groups]).to include(
            "You cannot remove a year group from the school once it has been added"
          )
        end
      end

      context "when editing and keeping all existing year groups" do
        let(:existing_site) do
          create(
            :gias_school,
            urn: school.urn,
            site: "A",
            gias_year_groups: [8, 9, 10]
          )
        end
        let(:attributes) do
          {
            editing_id: existing_site.id,
            wizard_step: :year_groups,
            selected_year_groups: [8, 9, 10, 11]
          }
        end

        it { should be_valid(:update) }
      end
    end

    context "on the confirm step" do
      let(:attributes) { valid_attributes.merge(wizard_step: :confirm) }

      it { should be_valid(:update) }
    end
  end

  describe "#wizard_steps" do
    context "when creating a new site" do
      let(:attributes) { { context: "add_site" } }

      it "returns all steps including school selection" do
        expect(draft_school.wizard_steps).to eq(
          %i[school details phase year_groups confirm]
        )
      end
    end

    context "when adding a school" do
      let(:attributes) { { context: "add_school" } }

      it "returns URN flow steps" do
        expect(draft_school.wizard_steps).to eq(
          %i[urn confirm_urn phase year_groups confirm]
        )
      end
    end

    context "when editing an existing site" do
      let(:attributes) { { editing_id: school.id, context: "add_site" } }

      it "skips the school selection step" do
        expect(draft_school.wizard_steps).to eq(
          %i[details phase year_groups confirm]
        )
      end
    end

    context "when editing an existing school (no site)" do
      let(:attributes) { { editing_id: school.id } }

      it "includes only details, year_groups and confirm" do
        expect(draft_school.wizard_steps).to eq(
          %i[details phase year_groups confirm]
        )
      end
    end
  end

  describe "#source_location" do
    context "when adding a new site" do
      context "when parent_urn_and_site is nil" do
        let(:attributes) { { parent_urn_and_site: nil } }

        it { expect(draft_school.source_location).to be_nil }
      end

      context "when parent_urn_and_site is set" do
        let(:attributes) { { parent_urn_and_site: school.urn_and_site } }

        it { expect(draft_school.source_location).to eq(school) }
      end

      context "when parent_urn_and_site does not match any school" do
        let(:attributes) { { parent_urn_and_site: "000000" } }

        it { expect(draft_school.source_location).to be_nil }
      end

      context "when school belongs to a different team" do
        let(:other_team) { create(:team) }
        let(:other_school) do
          create(:gias_school, :secondary, team: other_team)
        end
        let(:attributes) { { parent_urn_and_site: other_school.urn_and_site } }

        it { expect(draft_school.source_location).to be_nil }
      end
    end

    context "when editing an existing site" do
      let(:existing_site) do
        create(:gias_school, urn: school.urn, site: "A", name: "Site A")
      end
      let(:attributes) { { editing_id: existing_site.id } }

      it "returns the location being edited" do
        expect(draft_school.source_location).to eq(existing_site)
      end
    end

    context "when adding a new school" do
      context "when urn is nil" do
        let(:attributes) { { context: "add_school", urn: nil } }

        it { expect(draft_school.source_location).to be_nil }
      end

      context "when urn is set" do
        let(:attributes) { { context: "add_school", urn: school.urn } }

        it { expect(draft_school.source_location).to eq(school) }
      end
    end
  end

  describe "#existing_names" do
    context "when urn_and_site is blank" do
      let(:attributes) { { parent_urn_and_site: nil } }

      it { expect(draft_school.existing_names).to eq([]) }
    end

    context "when urn_and_site is set" do
      let(:attributes) { { parent_urn_and_site: school.urn_and_site } }

      it "returns names of schools with the same URN" do
        expect(draft_school.existing_names).to include(school.name)
      end
    end

    context "when multiple sites exist with the same URN" do
      before do
        create(
          :gias_school,
          :secondary,
          urn: school.urn,
          site: "A",
          name: "School Site A"
        )
        create(
          :gias_school,
          :secondary,
          urn: school.urn,
          site: "B",
          name: "School Site B"
        )
      end

      let(:attributes) { { parent_urn_and_site: school.urn_and_site } }

      it "returns all site names" do
        expect(draft_school.existing_names).to include(
          school.name,
          "School Site A",
          "School Site B"
        )
      end
    end
  end

  describe "#request_session_key" do
    let(:attributes) { {} }

    it { expect(draft_school.request_session_key).to eq("draft_school") }
  end

  describe "#address_parts" do
    context "with all address fields" do
      let(:attributes) { valid_attributes }

      it "returns all address parts" do
        expect(draft_school.address_parts).to eq(
          ["123 Main Street", "Floor 2", "London", "SW1A 1AA"]
        )
      end
    end

    context "with some blank fields" do
      let(:attributes) do
        valid_attributes.merge(address_line_2: nil, address_town: "")
      end

      it "excludes blank fields" do
        expect(draft_school.address_parts).to eq(
          ["123 Main Street", "SW1A 1AA"]
        )
      end
    end

    context "with no address fields" do
      let(:attributes) { {} }

      it { expect(draft_school.address_parts).to eq([]) }
    end
  end

  describe "normalization" do
    let(:attributes) { valid_attributes.merge(wizard_step: :details) }

    it "normalises whitespace in name" do
      draft_school.name = "  School   Name  "
      draft_school.valid?(:update)
      expect(draft_school.name).to eq("School Name")
    end

    it "removes zero-width joiners from name" do
      draft_school.name = "School\u200DName"
      draft_school.valid?(:update)
      expect(draft_school.name).to eq("SchoolName")
    end

    it "removes non-breaking spaces from name" do
      draft_school.name = "School\u00A0Name"
      draft_school.valid?(:update)
      expect(draft_school.name).to eq("School Name")
    end

    it "normalises whitespace in address_line_1" do
      draft_school.address_line_1 = "  123   Main   Street  "
      draft_school.valid?(:update)
      expect(draft_school.address_line_1).to eq("123 Main Street")
    end

    it "removes zero-width joiners from address_line_1" do
      draft_school.address_line_1 = "123\u200DMain\u200DStreet"
      draft_school.valid?(:update)
      expect(draft_school.address_line_1).to eq("123MainStreet")
    end

    it "normalises whitespace in address_line_2" do
      draft_school.address_line_2 = "  Floor   2  "
      draft_school.valid?(:update)
      expect(draft_school.address_line_2).to eq("Floor 2")
    end

    it "normalises whitespace in address_town" do
      draft_school.address_town = "  Greater   London  "
      draft_school.valid?(:update)
      expect(draft_school.address_town).to eq("Greater London")
    end

    it "returns nil for blank values after normalization" do
      draft_school.address_line_2 = "   "
      draft_school.valid?(:update)
      expect(draft_school.address_line_2).to be_nil
    end
  end

  describe "session persistence" do
    let(:attributes) { valid_attributes }

    it "persists to session on save" do
      draft_school.save!
      expect(request_session["draft_school"]).to eq(
        {
          "address_line_1" => "123 Main Street",
          "address_line_2" => "Floor 2",
          "address_postcode" => "SW1A 1AA",
          "address_town" => "London",
          "confirm_school" => nil,
          "context" => "add_site",
          "editing_id" => nil,
          "name" => "New Site Name",
          "parent_urn_and_site" => school.urn_and_site,
          "phase" => nil,
          "selected_year_groups" => [],
          "urn" => nil
        }
      )
    end

    it "clears session on clear!" do
      draft_school.save!
      draft_school.clear!
      expect(request_session["draft_school"]).to eq(
        {
          "address_line_1" => nil,
          "address_line_2" => nil,
          "address_postcode" => nil,
          "address_town" => nil,
          "confirm_school" => nil,
          "context" => nil,
          "editing_id" => nil,
          "name" => nil,
          "parent_urn_and_site" => nil,
          "phase" => nil,
          "selected_year_groups" => nil,
          "urn" => nil
        }
      )
    end
  end

  describe "#urn_and_site" do
    context "when creating a new site" do
      let(:attributes) { valid_attributes }

      it "returns the URN with the next site letter" do
        expect(draft_school.urn_and_site).to eq("#{school.urn}B")
      end

      context "when sites already exist" do
        before do
          create(:gias_school, urn: school.urn, site: "A", name: "Site A")
          create(:gias_school, urn: school.urn, site: "B", name: "Site B")
        end

        it "returns the URN with the next available site letter" do
          expect(draft_school.urn_and_site).to eq("#{school.urn}C")
        end
      end
    end

    context "when editing an existing site" do
      let(:existing_site) do
        create(:gias_school, urn: school.urn, site: "A", name: "Site A")
      end
      let(:attributes) { { editing_id: existing_site.id } }

      it "returns the location's urn_and_site" do
        expect(draft_school.urn_and_site).to eq(existing_site.urn_and_site)
      end
    end
  end

  describe "#resolved_urn" do
    context "when creating a new site" do
      let(:attributes) { valid_attributes.merge(context: "add_site") }

      it "returns the parent school's URN" do
        expect(draft_school.resolved_urn).to eq(school.urn)
      end
    end

    context "when editing an existing site" do
      let(:existing_site) do
        create(:gias_school, urn: "654321", site: "A", name: "Site A")
      end
      let(:attributes) { { editing_id: existing_site.id, context: "add_site" } }

      it "returns the location's URN" do
        expect(draft_school.resolved_urn).to eq("654321")
      end
    end
  end

  describe "#next_site_letter" do
    let(:attributes) { valid_attributes }

    context "when no sites exist" do
      it "returns B" do
        expect(draft_school.next_site_letter).to eq("B")
      end
    end

    context "when site A exists" do
      before { create(:gias_school, urn: school.urn, site: "A") }

      it "returns B" do
        expect(draft_school.next_site_letter).to eq("B")
      end
    end

    context "when sites A and B exist" do
      before do
        create(:gias_school, urn: school.urn, site: "A")
        create(:gias_school, urn: school.urn, site: "B")
      end

      it "returns C" do
        expect(draft_school.next_site_letter).to eq("C")
      end
    end

    context "when site Z exists" do
      before { create(:gias_school, urn: school.urn, site: "Z") }

      it "returns AA" do
        expect(draft_school.next_site_letter).to eq("AA")
      end
    end
  end

  describe "#year_groups" do
    context "when creating a new site" do
      let(:attributes) { valid_attributes }

      it "returns the parent school's year groups" do
        expect(draft_school.year_groups).to eq(school.year_groups)
      end
    end

    context "when editing an existing site" do
      let(:existing_site) do
        create(
          :gias_school,
          urn: school.urn,
          site: "A",
          gias_year_groups: [10, 11]
        )
      end
      let(:attributes) { { editing_id: existing_site.id } }

      it "returns the location's year groups" do
        expect(draft_school.year_groups).to eq(existing_site.year_groups)
      end
    end

    context "when selected_year_groups is set" do
      let(:attributes) { valid_attributes.merge(selected_year_groups: [8, 9]) }

      it "returns the explicitly selected year groups over the existing ones" do
        expect(draft_school.year_groups).to eq([8, 9])
      end
    end
  end

  describe "#programmes" do
    context "when creating a new site" do
      let(:programmes) { [Programme.hpv] }
      let(:attributes) { valid_attributes }

      it "returns the parent school's programmes" do
        expect(draft_school.programmes).to match_array(school.programmes)
      end
    end

    context "when editing an existing site" do
      let(:programmes) { [Programme.hpv, Programme.flu] }
      let(:existing_site) do
        create(:gias_school, urn: school.urn, site: "A", team:, programmes:)
      end
      let(:attributes) { { editing_id: existing_site.id } }

      it "returns the location's programmes" do
        expect(draft_school.programmes).to match_array(programmes)
      end
    end
  end

  describe "#readable_attribute_names" do
    let(:attributes) { {} }

    it "returns the list of readable attributes" do
      expect(draft_school.readable_attribute_names).to eq(
        %w[
          name
          address_line_1
          address_line_2
          address_town
          address_postcode
          phase
        ]
      )
    end
  end

  describe "#writable_attribute_names" do
    let(:attributes) { {} }

    it "returns the list of writable attributes" do
      expect(draft_school.writable_attribute_names).to eq(
        %w[
          name
          address_line_1
          address_line_2
          address_town
          address_postcode
          phase
        ]
      )
    end
  end
end
