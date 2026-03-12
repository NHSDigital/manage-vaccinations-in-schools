# frozen_string_literal: true

describe GenericLocationFactory do
  describe "#call" do
    subject(:call) { described_class.call(team:, academic_year:) }

    let(:programmes) { [Programme.hpv, Programme.flu] }
    let(:academic_year) { AcademicYear.pending }

    let(:expected_year_groups) do
      [-3, -2, -1, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
    end

    context "with a new team" do
      let(:team) { create(:team, programmes:) }

      it "creates a generic clinic location" do
        locations = Location.generic_clinic

        expect { call }.to change(locations, :count).by(1)

        location = locations.first
        expect(location.teams).to contain_exactly(team)

        expect(
          location.location_year_groups.where(academic_year:).pluck_values
        ).to eq(expected_year_groups)
      end

      it "creates two generic school locations" do
        locations = Location.generic_school

        expect { call }.to change(locations, :count).by(2)

        home_educated_school_location =
          locations.find_by!(urn: Location::URN_HOME_EDUCATED)
        expect(home_educated_school_location.teams).to contain_exactly(team)
        expect(
          home_educated_school_location
            .location_year_groups
            .where(academic_year:)
            .pluck_values
        ).to eq(expected_year_groups)

        unknown_school_location = locations.find_by!(urn: Location::URN_UNKNOWN)
        expect(unknown_school_location.teams).to contain_exactly(team)
        expect(
          unknown_school_location
            .location_year_groups
            .where(academic_year:)
            .pluck_values
        ).to eq(expected_year_groups)
      end
    end

    context "with an existing team" do
      let(:team) { create(:team, programmes:) }

      it "doesn't create a generic clinic location" do
        team

        expect { call }.not_to change(Location.generic_clinic, :count)
      end

      it "doesn't create generic school locations" do
        team

        expect { call }.not_to change(Location.generic_school, :count)
      end
    end
  end
end
