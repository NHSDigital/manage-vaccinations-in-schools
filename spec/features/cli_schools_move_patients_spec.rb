# frozen_string_literal: true

describe "schools move-patients" do
  subject(:command) do
    Dry::CLI.new(MavisCLI).call(
      arguments: ["schools", "move-patients", source_urn, target_urn]
    )
  end

  let(:team) { create(:team) }
  let(:subteam) { create(:subteam, team:) }
  let(:other_subteam) { create(:subteam, team:) }
  let(:source_school) { create(:gias_school, team:, subteam:) }
  let(:target_school) { create(:gias_school, team:) }
  let(:programmes) { [Programme.hpv] }
  let(:location_programme_year_group) do
    create(
      :location_programme_year_group,
      location: source_school,
      programme: programmes.first
    )
  end
  let!(:patient) { create(:patient, school: source_school) }
  let!(:session) do
    create(:session, location: source_school, programmes:, team:)
  end
  let!(:school_move) { create(:school_move, patient:, school: source_school) }
  let!(:consent_form) { create(:consent_form, school: source_school, session:) }
  let(:other_org_school) { create(:gias_school, subteam: other_subteam) }

  let(:source_urn) { source_school.urn.to_s }
  let(:target_urn) { target_school.urn.to_s }

  it "transfers associated records from source to target school" do
    expect { command }.to change { patient.reload.school }.from(
      source_school
    ).to(target_school).and change { consent_form.reload.school }.from(
            source_school
          ).to(target_school).and change { consent_form.reload.location }.from(
                  source_school
                ).to(target_school).and change { session.reload.location }.from(
                        source_school
                      ).to(target_school).and change {
                              school_move.reload.school
                            }.from(source_school).to(target_school).and change {
                                    location_programme_year_group.reload.location
                                  }.from(source_school).to(target_school)

    expect(patient.school).to eq(target_school)
    expect(consent_form.school).to eq(target_school)
    expect(consent_form.location).to eq(target_school)
    expect(session.location).to eq(target_school)
    expect(school_move.school).to eq(target_school)
  end

  context "when source school ID is invalid" do
    let(:source_urn) { "999999" }

    it "raises an error" do
      expect { command }.to output(
        /Could not find one or both schools./
      ).to_stderr
    end
  end

  context "when target school ID is invalid" do
    let(:target_urn) { "999999" }

    it "raises an error" do
      expect { command }.to output(
        /Could not find one or both schools./
      ).to_stderr
    end
  end
end
