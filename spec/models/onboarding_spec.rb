# frozen_string_literal: true

describe Onboarding do
  subject(:onboarding) { described_class.new(config) }

  let(:config) do
    YAML.safe_load(file_fixture(filename).read, permitted_classes: [Date])
  end

  let!(:programmes) { [Programme.hpv] }
  # rubocop:disable RSpec/IndexedLet
  let!(:school1) { create(:gias_school, :secondary, :open, urn: "123456") }
  let!(:school2) { create(:gias_school, :secondary, :open, urn: "234567") }
  let!(:school3) { create(:gias_school, :secondary, :open, urn: "345678") }
  let!(:school4) { create(:gias_school, :secondary, :open, urn: "456789") }
  # rubocop:enable RSpec/IndexedLet

  before { create(:gias_school, :secondary, :closed, urn: "567890") }

  context "with a valid configuration file for a point of care team" do
    let(:filename) { "onboarding/point_of_care_valid.yaml" }

    it { should be_valid }

    it "set up the models" do
      expect { onboarding.save! }.not_to raise_error

      organisation = Organisation.find_by(ods_code: "EXAMPLE")
      expect(organisation).not_to be_nil

      team = Team.find_by(organisation:, name: "NHS Trust")
      expect(team.email).to eq("example@trust.nhs.uk")
      expect(team.phone).to eq("07700 900815")
      expect(team.phone_instructions).to eq("option 1, followed by option 3")
      expect(team.careplus_venue_code).to eq("EXAMPLE")
      expect(team.careplus_staff_code).to eq("ABCD")
      expect(team.careplus_staff_type).to eq("PQ")
      expect(team.programmes).to match_array(programmes)

      expect(team.locations.generic_clinic.count).to eq(1)
      generic_clinic = team.locations.generic_clinic.first
      expect(generic_clinic.year_groups.count).to eq(19)
      expect(generic_clinic.location_programme_year_groups.count).to eq(4)

      subteam1 =
        team.subteams.includes(:gias_schools).find_by!(name: "Subteam 1")
      expect(subteam1.email).to eq("subteam-1@trust.nhs.uk")
      expect(subteam1.phone).to eq("07700 900816")
      expect(subteam1.phone_instructions).to eq("option 9")
      expect(subteam1.reply_to_id).to eq("24af66c3-d6bd-4b9f-8067-3844f49e08d0")

      subteam2 =
        team.subteams.includes(:gias_schools).find_by!(name: "Subteam 2")
      expect(subteam2.email).to eq("subteam-2@trust.nhs.uk")
      expect(subteam2.phone).to eq("07700 900817")
      expect(subteam2.reply_to_id).to be_nil

      school2_sites = Location.where(urn: school2.urn).where.not(site: nil)
      school4_sites = Location.where(urn: school4.urn).where.not(site: nil)

      expect(subteam1.gias_schools).to contain_exactly(school1, *school2_sites)
      expect(subteam2.gias_schools).to contain_exactly(school3, *school4_sites)

      expect(school1.location_programme_year_groups.count).to eq(4)
      expect(school2_sites.first.location_programme_year_groups.count).to eq(4)
      expect(school2_sites.second.location_programme_year_groups.count).to eq(4)
      expect(school3.location_programme_year_groups.count).to eq(4)
      expect(school4_sites.first.location_programme_year_groups.count).to eq(4)
      expect(school4_sites.second.location_programme_year_groups.count).to eq(4)

      clinic1 = subteam1.community_clinics.find_by!(ods_code: nil)
      expect(clinic1.name).to eq("10 Downing Street")
      expect(clinic1.address_postcode).to eq("SW1A 1AA")
      expect(LocationPositionUpdaterJob).to have_enqueued_sidekiq_job(
        clinic1.id
      )

      clinic2 = subteam2.community_clinics.find_by!(ods_code: "SW1A11")
      expect(clinic2.name).to eq("11 Downing Street")
      expect(clinic2.address_postcode).to eq("SW1A 1AA")
      expect(LocationPositionUpdaterJob).to have_enqueued_sidekiq_job(
        clinic2.id
      )
    end
  end

  context "with a valid configuration file for a national reporting team" do
    let(:filename) { "onboarding/national_reporting_valid.yaml" }

    let(:programmes) { [Programme.hpv, Programme.flu] }

    it { should be_valid }

    it "set up the models" do
      expect { onboarding.save! }.not_to raise_error

      organisation = Organisation.find_by(ods_code: "EXAMPLE")
      expect(organisation).not_to be_nil

      team = Team.find_by(organisation:, name: "NHS Trust")
      expect(team.email).to be_nil
      expect(team.phone).to be_nil
      expect(team.phone_instructions).to be_nil
      expect(team.careplus_venue_code).to be_nil
      expect(team.careplus_staff_code).to be_nil
      expect(team.careplus_staff_type).to be_nil
      expect(team.programmes).to match_array(programmes)
      expect(team.national_reporting_cut_off_date).to eq(Date.new(2026, 1, 1))

      expect(team.locations.generic_clinic.count).to eq(1)
      expect(team.locations.community_clinic.count).to eq(0)

      expect(team.subteams.count).to eq(0)

      expect(team.gias_schools.count).to eq(0)
    end
  end

  context "with an invalid configuration file" do
    let(:filename) { "onboarding/invalid.yaml" }

    let(:team) { create(:team, name: "Existing Team") }

    before do
      create(:gias_school, :secondary, :open, urn: "111111", team:)
      create(:gias_school, :secondary, :open, urn: "555555", team:)
      create(
        :gias_school,
        :secondary,
        :open,
        urn: "222222",
        name: "School with no site"
      )
      create(
        :gias_school,
        :secondary,
        :open,
        urn: "222222",
        site: "A",
        name: "School with Site A",
        team:
      )
      create(
        :gias_school,
        :secondary,
        :open,
        urn: "222222",
        site: "B",
        name: "School with Site B",
        team:
      )
    end

    it { should be_invalid }

    it "has errors" do
      onboarding.invalid?

      expect(onboarding.errors.messages).to eq(
        {
          "team.name": ["Enter a name"],
          "team.type": ["Choose a type"],
          "team.workgroup": ["Enter a workgroup"],
          "school.0.subteam": ["can't be blank"],
          "school.1.subteam": ["can't be blank"],
          "school.5.urn": [
            "URN 111111 is already attached to teams: Existing Team"
          ],
          "school.6.urn": [
            "URN 222222 has sites (A, B) already attached to teams: Existing Team"
          ],
          "school.7.urn": [
            "URN 555555 is already attached to teams: Existing Team"
          ],
          schools: [
            "URN(s) 456789 cannot appear as both a regular school and a site"
          ],
          "subteam.email": ["can't be blank"],
          "subteam.name": ["Enter a name"],
          clinics: ["Choose at least one clinic"],
          programmes: ["Choose at least one programme"]
        }
      )
    end
  end
end
