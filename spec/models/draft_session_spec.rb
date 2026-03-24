# frozen_string_literal: true

describe DraftSession do
  subject(:draft_session) do
    instance = described_class.new(request_session:, current_user:)
    instance.read_from!(session)
    instance.assign_attributes(attributes)
    instance
  end

  let(:team) do
    create(
      :team,
      :with_one_nurse,
      programmes: existing_programmes + [new_programme]
    )
  end

  let(:request_session) { {} }
  let(:current_user) { team.users.first }

  let(:existing_programmes) { [Programme.menacwy, Programme.td_ipv] }
  let(:new_programme) { Programme.hpv }

  let(:location) { create(:school, team:, programmes: existing_programmes) }
  let(:session) do
    create(:session, team:, location:, programmes: existing_programmes)
  end
  let(:programme_types) do
    existing_programmes.map(&:type) + [new_programme.type]
  end

  let(:attributes) { { programme_types:, wizard_step: :programmes } }

  describe "validations" do
    it { should be_valid }

    context "when attempting to remove a programme" do
      let(:programme_types) { [existing_programmes.first.id] }

      it "is invalid" do
        expect(draft_session.save(context: :update)).to be(false)
        expect(draft_session.errors[:programme_types]).to include(
          "You cannot remove a programme from the session once it has been added"
        )
      end
    end
  end

  describe "#year_groups" do
    subject(:year_groups) { draft_session.year_groups }

    it { should all(be_a(Integer)) }
  end

  describe "#can_change_year_groups?" do
    subject { draft_session.can_change_year_groups? }

    context "when creating a clinic session" do
      let(:location) { team.generic_clinic }

      let(:attributes) { { editing_id: nil } }

      it { should be(false) }
    end

    context "when creating a school session" do
      let(:attributes) { { editing_id: nil } }

      it { should be(true) }
    end

    context "when editing a school session" do
      context "and the consent window is open" do
        let(:session) do
          create(
            :session,
            date: Date.tomorrow,
            team:,
            location:,
            programmes: existing_programmes
          )
        end

        it { should be(false) }
      end

      context "and the consent window isn't open yet" do
        let(:session) do
          create(
            :session,
            date: 3.months.from_now.to_date,
            team:,
            location:,
            programmes: existing_programmes
          )
        end

        it { should be(true) }
      end
    end
  end

  describe "#supports_oubreak?" do
    subject { draft_session.supports_outbreak? }

    context "when the programme supports outbreak" do
      let(:existing_programmes) { [Programme.mmr] }

      it { should be true }
    end

    context "when the session isn't part of an outbreak" do
      let(:existing_programmes) { [Programme.flu] }

      it { should be false }
    end
  end
end
