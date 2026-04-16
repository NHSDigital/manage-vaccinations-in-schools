# frozen_string_literal: true

# == Schema Information
#
# Table name: locations
#
#  id                        :bigint           not null, primary key
#  address_line_1            :text
#  address_line_2            :text
#  address_postcode          :text
#  address_town              :text
#  gias_establishment_number :integer
#  gias_local_authority_code :integer
#  gias_phase                :integer
#  gias_year_groups          :integer          default([]), not null, is an Array
#  name                      :text             not null
#  ods_code                  :string
#  site                      :string
#  status                    :integer          default("unknown"), not null
#  systm_one_code            :string
#  type                      :integer          not null
#  url                       :text
#  urn                       :string
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#
# Indexes
#
#  index_locations_on_ods_code        (ods_code) UNIQUE
#  index_locations_on_systm_one_code  (systm_one_code) UNIQUE
#  index_locations_on_urn             (urn) UNIQUE WHERE ((type = 0) AND (site IS NULL))
#  index_locations_on_urn_and_site    (urn,site) UNIQUE
#

describe Location do
  subject(:location) { build(:location) }

  describe "associations" do
    it { should have_many(:location_programme_year_groups) }

    describe "local_authority" do
      context "when the location has a gias_local_authority_code" do
        let!(:local_authority) { create(:local_authority, gias_code: 111) }

        before do
          create(:local_authority, gias_code: 222)
          location.gias_local_authority_code = local_authority.gias_code
        end

        it "returns the local_authority with that code" do
          expect(location.local_authority).to eq(local_authority)
        end
      end
    end
  end

  describe "scopes" do
    describe "#find_by_urn_and_site" do
      subject(:scope) { described_class.find_by_urn_and_site(urn_and_site) }

      let(:location_without_site) { create(:gias_school, urn: "123456") }
      let(:location_with_site) do
        create(:gias_school, urn: "123456", site: "A")
      end

      context "with just a URN" do
        let(:urn_and_site) { "123456" }

        it { should eq(location_without_site) }
      end

      context "with a URN and a site" do
        let(:urn_and_site) { "123456A" }

        it { should eq(location_with_site) }
      end
    end

    describe "#search_by_name" do
      subject(:scope) { described_class.search_by_name(query) }

      let(:clinic) { create(:generic_clinic) }
      let!(:school_a) { create(:gias_school, name: "St. John's School") }
      let!(:school_b) do
        create(:gias_school, name: "St. John's School for Boys")
      end
      let!(:school_c) do
        create(
          :gias_school,
          name: "St. John's Primary School for Boys with learning disabilities"
        )
      end
      let!(:school_d) do
        create(:gias_school, name: "St. Mary's School for Girls")
      end

      context "with an exact match on the name" do
        let(:query) { "Community clinic" }

        it { should contain_exactly(clinic) }
      end

      context "without a match" do
        let(:query) { "Some other location" }

        it { should_not contain_exactly(clinic) }
      end

      context "when searching with just the start of a name" do
        let(:query) { "St. J" }

        it { should include(school_a, school_b, school_c) }
      end

      context "with a query matching the name of school A" do
        let(:query) { "St. John's School" }

        it { should eq([school_a, school_b, school_c]) }
      end

      context "with a query matching the name of school B" do
        let(:query) { "St. John's School for Boys" }

        it { should start_with(school_b) }
        it { should include(school_c) }
        it { should_not include(school_d) }
      end

      context "with a query matching the name of a school C" do
        let(:query) do
          "St. John's Primary School for Boys with learning disabilities"
        end

        it { should eq([school_c]) }
        it { should_not include(school_d) }
      end

      context "with an overly generic search term" do
        let(:query) { "school" }

        it { should contain_exactly(school_a, school_b, school_c, school_d) }
      end

      context "with typos" do
        let(:query) { "Saint John's school" }

        it { should start_with([school_a, school_b]) }
      end
    end

    describe "#where_phase" do
      subject { described_class.where_phase(phase) }

      let!(:nursery) { create(:gias_school, gias_phase: "nursery") }
      let!(:primary) { create(:gias_school, gias_phase: "primary") }
      let!(:middle_deemed_primary) do
        create(:gias_school, gias_phase: "middle_deemed_primary")
      end
      let!(:secondary) { create(:gias_school, gias_phase: "secondary") }
      let!(:middle_deemed_secondary) do
        create(:gias_school, gias_phase: "middle_deemed_secondary")
      end
      let!(:sixteen_plus) { create(:gias_school, gias_phase: "sixteen_plus") }
      let!(:all_through) { create(:gias_school, gias_phase: "all_through") }
      let!(:not_applicable) do
        create(:gias_school, gias_phase: "not_applicable")
      end

      context "with nursery" do
        let(:phase) { "nursery" }

        it { should contain_exactly(nursery) }
      end

      context "with primary" do
        let(:phase) { "primary" }

        it { should contain_exactly(primary, middle_deemed_primary) }
      end

      context "with secondary" do
        let(:phase) { "secondary" }

        it { should contain_exactly(secondary, middle_deemed_secondary) }
      end

      context "with other" do
        let(:phase) { "other" }

        it { should contain_exactly(sixteen_plus, all_through, not_applicable) }
      end
    end
  end

  describe "normalisations" do
    it { should normalize(:address_postcode).from(" SW111AA ").to("SW11 1AA") }
    it { should normalize(:ods_code).from(" r1a ").to("R1A") }
    it { should normalize(:urn).from(" 123 ").to("123") }
  end

  describe "validations" do
    it { should validate_presence_of(:name) }

    context "with a community clinic" do
      subject(:location) { build(:community_clinic, team:) }

      let(:team) { create(:team) }
      let(:team_ods_code) { team.organisation.ods_code }

      it { should validate_absence_of(:gias_establishment_number) }
      it { should validate_absence_of(:gias_local_authority_code) }
      it { should validate_absence_of(:gias_phase) }
      it { should_not validate_absence_of(:ods_code) }
      it { should_not validate_presence_of(:ods_code) }
      it { should validate_exclusion_of(:ods_code).in_array([team_ods_code]) }
      it { should validate_uniqueness_of(:ods_code).ignoring_case_sensitivity }
      it { should validate_absence_of(:urn) }
      it { should validate_absence_of(:site) }
    end

    context "with a generic clinic" do
      subject(:location) { build(:generic_clinic, team:) }

      let(:team) { create(:team) }

      it { should validate_absence_of(:gias_establishment_number) }
      it { should validate_absence_of(:gias_local_authority_code) }
      it { should validate_absence_of(:gias_phase) }
      it { should validate_absence_of(:ods_code) }
      it { should validate_absence_of(:urn) }
      it { should validate_absence_of(:site) }
    end

    context "with a generic school" do
      subject(:location) { build(:generic_school) }

      it { should validate_absence_of(:gias_establishment_number) }
      it { should validate_absence_of(:gias_local_authority_code) }
      it { should validate_absence_of(:ods_code) }
      it { should validate_inclusion_of(:urn).in_array(%w[888888 999999]) }
      it { should validate_absence_of(:site) }
    end

    context "with a GP practice" do
      subject(:location) { build(:gp_practice, ods_code: "abc") }

      it { should validate_absence_of(:gias_establishment_number) }
      it { should validate_absence_of(:gias_local_authority_code) }
      it { should validate_absence_of(:gias_phase) }
      it { should validate_presence_of(:ods_code) }
      it { should validate_uniqueness_of(:ods_code).ignoring_case_sensitivity }
      it { should validate_absence_of(:urn) }
      it { should validate_absence_of(:site) }
    end

    context "with a school" do
      subject(:location) { build(:gias_school, urn: "abc") }

      it { should validate_presence_of(:gias_establishment_number) }
      it { should validate_presence_of(:gias_local_authority_code) }
      it { should validate_absence_of(:ods_code) }
      it { should_not validate_absence_of(:site) }
      it { should_not validate_presence_of(:site) }
      it { should validate_presence_of(:urn) }
      it { should validate_uniqueness_of(:urn) }
    end
  end

  describe "#to_param" do
    subject { location.to_param }

    context "with a community clinic with an ODS code" do
      let(:location) { create(:community_clinic, ods_code: "ABC") }

      it { should eq(location.ods_code) }
    end

    context "with a community clinic without an ODS code" do
      let(:location) { create(:community_clinic, ods_code: nil) }

      it { should eq(location.id) }
    end

    context "with a generic clinic" do
      let(:location) { create(:generic_clinic, team: create(:team)) }

      it { should eq(location.id) }
    end

    context "with a GP practice" do
      let(:location) { create(:gp_practice) }

      it { should eq(location.ods_code) }
    end

    context "with a school" do
      let(:location) { create(:gias_school) }

      it { should be(location.urn_and_site) }
    end
  end

  describe "#clinic?" do
    subject(:clinic?) { location.clinic? }

    context "with a community clinic" do
      let(:location) { build(:community_clinic) }

      it { should be(true) }
    end

    context "with a generic clinic" do
      let(:location) { build(:generic_clinic) }

      it { should be(true) }
    end

    context "with a school" do
      let(:location) { build(:gias_school) }

      it { should be(false) }
    end
  end

  describe "#dfe_number" do
    subject(:dfe_number) { location.dfe_number }

    context "with a community clinic" do
      let(:location) { build(:community_clinic) }

      it { should be_nil }
    end

    context "with a generic clinic" do
      let(:location) { build(:generic_clinic) }

      it { should be_nil }
    end

    context "with a school" do
      let(:location) do
        build(
          :gias_school,
          gias_local_authority_code: 123,
          gias_establishment_number: 456
        )
      end

      it { should eq("123456") }
    end
  end

  describe "#phase" do
    subject { location.phase }

    context "with a nursery GIAS phase" do
      let(:location) { build(:gias_school, gias_phase: "nursery") }

      it { should eq("nursery") }
    end

    context "with a primary GIAS phase" do
      let(:location) { build(:gias_school, gias_phase: "primary") }

      it { should eq("primary") }
    end

    context "with a middle deemed primary GIAS phase" do
      let(:location) do
        build(:gias_school, gias_phase: "middle_deemed_primary")
      end

      it { should eq("primary") }
    end

    context "with a secondary GIAS phase" do
      let(:location) { build(:gias_school, gias_phase: "secondary") }

      it { should eq("secondary") }
    end

    context "with a middle deemed secondary GIAS phase" do
      let(:location) do
        build(:gias_school, gias_phase: "middle_deemed_secondary")
      end

      it { should eq("secondary") }
    end

    context "with a 16-plus phase" do
      let(:location) { build(:gias_school, gias_phase: "sixteen_plus") }

      it { should eq("other") }
    end

    context "with an all-through phase" do
      let(:location) { build(:gias_school, gias_phase: "all_through") }

      it { should eq("other") }
    end

    context "with a not applicable phase" do
      let(:location) { build(:gias_school, gias_phase: "not_applicable") }

      it { should eq("other") }
    end

    context "with something other than a school" do
      let(:location) { build(:community_clinic) }

      it { should be_nil }
    end
  end

  describe "#as_json" do
    subject(:as_json) { location.as_json }

    let(:location) { create(:community_clinic) }

    it do
      expect(as_json).to eq(
        {
          "address_line_1" => location.address_line_1,
          "address_line_2" => location.address_line_2,
          "address_postcode" => location.address_postcode,
          "address_town" => location.address_town,
          "gias_establishment_number" => nil,
          "gias_local_authority_code" => nil,
          "gias_phase" => nil,
          "gias_year_groups" => [],
          "id" => location.id,
          "is_attached_to_team" => false,
          "name" => location.name,
          "ods_code" => location.ods_code,
          "site" => location.site,
          "status" => "unknown",
          "type" => "community_clinic",
          "url" => location.url,
          "urn" => nil
        }
      )
    end

    context "when the location is not attached to a team" do
      let(:location) { create(:gias_school, subteam: nil) }

      it { should include("is_attached_to_team" => false) }
    end
  end

  describe "#import_default_programme_year_groups!" do
    subject(:import_default_programme_year_groups!) do
      location.import_default_programme_year_groups!(programmes, academic_year:)
    end

    let(:programmes) { [Programme.flu] } # years 0 to 11
    let(:academic_year) { AcademicYear.pending }

    context "when the location has no year groups" do
      let(:location) { create(:gias_school, gias_year_groups: []) }

      it "doesn't create any programme year groups" do
        expect { import_default_programme_year_groups! }.not_to change(
          location.location_programme_year_groups,
          :count
        )
      end
    end

    context "when the location has fewer year groups than the default" do
      let(:location) { create(:gias_school, gias_year_groups: (0..3).to_a) }

      it "creates only suitable year groups" do
        expect { import_default_programme_year_groups! }.to change(
          location.location_programme_year_groups,
          :count
        ).by(4)

        expect(location.location_programme_year_groups.pluck_year_groups).to eq(
          (0..3).to_a
        )
      end
    end

    context "when the location has more year groups than the default" do
      let(:location) { create(:gias_school, gias_year_groups: (-1..14).to_a) }

      it "creates only suitable year groups" do
        expect { import_default_programme_year_groups! }.to change(
          location.location_programme_year_groups,
          :count
        ).by(12)

        expect(location.location_programme_year_groups.pluck_year_groups).to eq(
          (0..11).to_a
        )
      end
    end
  end

  describe "#teams_for_academic_year" do
    subject(:teams_for_academic_year) do
      location.teams_for_academic_year(target_year)
    end

    let(:location) { create(:gias_school) }
    let(:team_a) { create(:team) }
    let(:team_b) { create(:team) }
    let(:team_c) { create(:team) }
    let(:current_year) { AcademicYear.current }
    let(:next_year) { AcademicYear.current + 1 }
    let(:target_year) { current_year }

    before do
      location.attach_to_team!(team_a, academic_year: current_year)
      location.attach_to_team!(team_b, academic_year: current_year)
      location.attach_to_team!(team_c, academic_year: next_year)
    end

    context "when requesting current academic year teams" do
      it "returns only teams for the current academic year" do
        expect(teams_for_academic_year).to contain_exactly(team_a, team_b)
      end

      it "does not return teams from other academic years" do
        expect(teams_for_academic_year).not_to include(team_c)
      end
    end

    context "when requesting next academic year teams" do
      let(:target_year) { next_year }

      it "returns only teams for the next academic year" do
        expect(teams_for_academic_year).to contain_exactly(team_c)
      end

      it "does not return teams from other academic years" do
        expect(teams_for_academic_year).not_to include(team_a, team_b)
      end
    end

    context "when the location has no teams for the specified year" do
      let(:location_without_teams) { create(:gias_school) }
      let(:pending_year) { AcademicYear.pending }

      it "returns an empty array" do
        expect(
          location_without_teams.teams_for_academic_year(pending_year)
        ).to be_empty
      end
    end
  end
end
