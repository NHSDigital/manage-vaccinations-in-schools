# frozen_string_literal: true

# == Schema Information
#
# Table name: teams
#
#  id                              :bigint           not null, primary key
#  careplus_password               :string
#  careplus_staff_code             :string
#  careplus_staff_type             :string
#  careplus_username               :string
#  careplus_venue_code             :string
#  days_before_consent_reminders   :integer          default(7), not null
#  days_before_consent_requests    :integer          default(21), not null
#  email                           :string
#  name                            :text             not null
#  national_reporting_cut_off_date :date
#  phone                           :string
#  phone_instructions              :string
#  privacy_notice_url              :string
#  privacy_policy_url              :string
#  programme_types                 :enum             not null, is an Array
#  type                            :integer          not null
#  workgroup                       :string           not null
#  created_at                      :datetime         not null
#  updated_at                      :datetime         not null
#  organisation_id                 :bigint           not null
#  reply_to_id                     :uuid
#
# Indexes
#
#  index_teams_on_name             (name) UNIQUE
#  index_teams_on_organisation_id  (organisation_id)
#  index_teams_on_programme_types  (programme_types) USING gin
#  index_teams_on_workgroup        (workgroup) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (organisation_id => organisations.id)
#

describe Team do
  subject(:team) { build(:team) }

  it_behaves_like "a Flipper actor"

  describe "associations" do
    it { should belong_to(:organisation) }
    it { should have_many(:archive_reasons) }
  end

  describe "validations" do
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:workgroup) }

    it do
      expect(team).to validate_inclusion_of(:type).in_array(
        %w[point_of_care national_reporting support]
      )
    end

    it { should validate_uniqueness_of(:name) }
    it { should validate_uniqueness_of(:workgroup) }

    context "when point_of_care" do
      subject(:team) { build(:team) }

      it { should validate_presence_of(:email) }
      it { should validate_presence_of(:phone) }
      it { should validate_presence_of(:privacy_notice_url) }
      it { should validate_presence_of(:privacy_policy_url) }
    end

    context "when national_reporting" do
      subject(:team) { build(:team, :national_reporting) }

      it { should_not validate_presence_of(:email) }
      it { should_not validate_presence_of(:phone) }
      it { should_not validate_presence_of(:privacy_notice_url) }
      it { should_not validate_presence_of(:privacy_policy_url) }
    end

    context "when support" do
      subject(:team) { build(:team, :support) }

      it { should_not validate_presence_of(:email) }
      it { should_not validate_presence_of(:phone) }
      it { should_not validate_presence_of(:privacy_notice_url) }
      it { should_not validate_presence_of(:privacy_policy_url) }
    end
  end

  it_behaves_like "a model with a normalised email address"
  it_behaves_like "a model with a normalised phone number"

  describe "#year_groups" do
    context "when team has national_reporting access" do
      let(:team) { create(:team, :national_reporting) }

      it "covers nursery to upper sixth" do
        expect(team.year_groups).to eq((-2..13).to_a)
      end

      it "ignores academic_year parameter" do
        expect(team.year_groups(academic_year: 2024)).to eq((-2..13).to_a)
      end
    end
  end

  describe "#is_sais_team?" do
    subject(:is_sais_team?) { team.is_sais_team? }

    context "with a point of care team" do
      let(:team) { create(:team) }

      it { should be(true) }
    end

    context "with a national reporting team" do
      let(:team) { create(:team, :national_reporting) }

      it { should be(true) }
    end

    context "with a support team" do
      let(:team) { create(:team, :support) }

      it { should be(false) }
    end
  end

  describe "#careplus_enabled?" do
    subject(:careplus_enabled?) { team.careplus_enabled? }

    context "when careplus_staff_code and careplus_staff_type are present" do
      let(:team) { create(:team, :with_careplus_enabled) }

      it { should be(true) }
    end

    context "when careplus_staff_code or careplus_staff_type are not present" do
      let(:team) do
        create(:team, careplus_staff_code: nil, careplus_staff_type: nil)
      end

      it { should be(false) }
    end
  end
end
