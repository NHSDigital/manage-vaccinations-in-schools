# frozen_string_literal: true

describe SchoolMoveForm do
  let(:user) { create(:user, team:) }
  let(:team) { create(:team) }
  let(:school_move) { create(:school_move, :to_home_educated, team:) }

  describe "#save" do
    context "when action is 'confirm'" do
      subject(:save_form) do
        described_class.new(
          school_move:,
          action: "confirm",
          current_user: user
        ).save
      end

      it_behaves_like "a method that updates team cached counts"
    end

    context "when action is 'ignore'" do
      subject(:save_form) do
        described_class.new(
          school_move:,
          action: "ignore",
          current_user: user
        ).save
      end

      it_behaves_like "a method that updates team cached counts"
    end
  end
end
