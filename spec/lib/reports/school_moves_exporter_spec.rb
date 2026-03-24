# frozen_string_literal: true

describe Reports::SchoolMovesExporter do
  subject(:exporter) { described_class.new(team:, start_date:, end_date:) }

  let(:team) { create(:team) }
  let(:start_date) { nil }
  let(:end_date) { nil }

  describe "#row_count" do
    subject { exporter.row_count }

    let(:one_day_ago) { 1.day.ago }
    let(:three_days_ago) { 3.days.ago }

    let(:school) { create(:gias_school, :secondary, team:) }

    before do
      3.times do
        patient = create(:patient, school:, team:)
        create(
          :school_move_log_entry,
          patient:,
          school:,
          created_at: one_day_ago
        )
      end

      2.times do
        patient = create(:patient, school:, team:)
        create(
          :school_move_log_entry,
          patient:,
          school:,
          created_at: three_days_ago
        )
      end
    end

    it { should eq(5) }

    context "when date range is specified" do
      let(:start_date) { one_day_ago }

      it { should eq(3) }
    end
  end

  describe "#csv_data" do
    subject(:csv_data) { exporter.csv_data }

    let(:rows) { CSV.parse(csv_data, headers: true) }

    context "with a standard school move" do
      let(:old_school) { create(:gias_school, :secondary, team:) }
      let(:new_school) { create(:gias_school, :secondary, team:) }

      before do
        patient = create(:patient, school: old_school, team:)
        create(:school_move_log_entry, patient:, school: new_school)
      end

      it "returns a CSV with the school moves data" do
        entry = SchoolMoveLogEntry.last

        expect(rows.first.to_hash).to include(
          {
            "NHS_REF" => entry.patient.nhs_number,
            "SURNAME" => entry.patient.family_name,
            "FORENAME" => entry.patient.given_name,
            "GENDER" => entry.patient.gender_code.humanize,
            "DOB" => entry.patient.date_of_birth.iso8601,
            "ADDRESS1" => entry.patient.address_line_1,
            "ADDRESS2" => entry.patient.address_line_2,
            "ADDRESS3" => nil,
            "TOWN" => entry.patient.address_town,
            "POSTCODE" => entry.patient.address_postcode,
            "COUNTY" => nil,
            "ETHNIC_OR" => nil,
            "ETHNIC_DESCRIPTION" => nil,
            "NATIONAL_URN_NO" => new_school.urn,
            "BASE_NAME" => new_school.name,
            "STARTDATE" => entry.created_at.iso8601,
            "STUD_ID" => nil,
            "DES_NUMBER" => nil
          }
        )
      end
    end

    context "when moving to home education" do
      before do
        session = create(:session, team:)
        patient = create(:patient, :home_educated, session:)
        create(:school_move_log_entry, :home_educated, patient:)
      end

      it "returns '999999' as the URN" do
        expect(rows.first["NATIONAL_URN_NO"]).to eq("999999")
      end
    end

    context "when moving to an unknown school" do
      before do
        session = create(:session, team:)
        patient = create(:patient, school: nil, session:)
        create(:school_move_log_entry, :unknown_school, patient:)
      end

      it "returns '888888' as the URN" do
        expect(rows.first["NATIONAL_URN_NO"]).to eq("888888")
      end
    end

    context "when moving to a school with a SystmOne code" do
      before do
        session = create(:session, team:)
        school = create(:gias_school, systm_one_code: "ABC")
        patient = create(:patient, school:, session:)
        create(:school_move_log_entry, :unknown_school, patient:)
      end

      it "returns 'ABC' as the URN" do
        expect(rows.first["NATIONAL_URN_NO"]).to eq("ABC")
      end
    end

    context "with multiple school moves for the same patient" do
      before do
        session = create(:session, team:)
        patient = create(:patient, school: nil, session:)
        new_school = create(:gias_school, urn: "123456", team: session.team)

        create(:school_move_log_entry, :unknown_school, patient:)
        create(:school_move_log_entry, :home_educated, patient:)
        create(:school_move_log_entry, school: new_school, patient:)
      end

      it "returns the URNs in the correct order" do
        expect(rows[0]["NATIONAL_URN_NO"]).to eq("888888")
        expect(rows[1]["NATIONAL_URN_NO"]).to eq("999999")
        expect(rows[2]["NATIONAL_URN_NO"]).to eq("123456")
      end
    end

    context "when a patient moves out of a team" do
      let(:team_a) { create(:team) }
      let(:team_b) { create(:team) }

      let(:school_a) { create(:gias_school, :secondary, team: team_a) }
      let(:school_b) { create(:gias_school, :secondary, team: team_b) }

      let(:session) { create(:session, team: team_b) }
      let(:patient) { create(:patient, session:) }

      let(:created_at_a) { 1.week.ago }
      let(:created_at_b) { Time.current }

      before do
        # first they were added to school 1
        create(
          :school_move_log_entry,
          patient:,
          school: school_a,
          created_at: created_at_a
        )

        # next they were moved to school 2
        create(
          :school_move_log_entry,
          patient:,
          school: school_b,
          created_at: created_at_b
        )
      end

      context "from the old team" do
        let(:team) { team_a }

        it "includes two rows" do
          expect(rows.count).to eq(2)
        end

        it "has the move in and the move out" do
          expect(rows[0].to_hash).to include(
            {
              "NHS_REF" => patient.nhs_number,
              "NATIONAL_URN_NO" => school_a.urn,
              "BASE_NAME" => school_a.name,
              "STARTDATE" => created_at_a.iso8601
            }
          )

          expect(rows[1].to_hash).to include(
            {
              "NHS_REF" => patient.nhs_number,
              "NATIONAL_URN_NO" => school_b.urn,
              "BASE_NAME" => school_b.name,
              "STARTDATE" => created_at_b.iso8601
            }
          )
        end
      end

      context "from the new team" do
        let(:team) { team_b }

        it "includes one row" do
          expect(rows.count).to eq(1)
        end

        it "has the move in" do
          expect(rows.first.to_hash).to include(
            {
              "NHS_REF" => patient.nhs_number,
              "NATIONAL_URN_NO" => school_b.urn,
              "BASE_NAME" => school_b.name,
              "STARTDATE" => created_at_b.iso8601
            }
          )
        end
      end
    end
  end
end
