# frozen_string_literal: true

describe ClinicSessionFactory do
  describe "#call" do
    subject(:call) do
      described_class.call(team:, academic_year:, programme_type:)
    end

    let(:team) { create(:team, programmes: [Programme.hpv, Programme.flu]) }
    let(:academic_year) { AcademicYear.pending }
    let(:programme_type) { "hpv" }

    context "with no existing session for today" do
      it "creates a new session" do
        expect { call }.to change(Session, :count).by(1)

        session = Session.last
        expect(session.team_location.team).to eq(team)
        expect(session.team_location.academic_year).to eq(academic_year)
        expect(session.dates).to contain_exactly(Date.current)
        expect(session.programme_types).to contain_exactly(programme_type)
      end
    end

    context "with a session today already for the same programme" do
      let(:location) { team.generic_clinic }

      let!(:existing_session) do
        create(
          :session,
          team:,
          location:,
          academic_year:,
          dates: [Date.current],
          programmes: team.programmes
        )
      end

      it "returns the existing session" do
        expect(call).to eq(existing_session)
      end

      it "doesn't create a new session" do
        expect { call }.not_to change(Session, :count)
      end

      it "doesn't change the programme types" do
        expect { call }.not_to(
          change { existing_session.reload.programme_types }
        )
      end
    end

    context "with a session for today already for a different programme" do
      let(:location) { team.generic_clinic }

      let!(:existing_session) do
        create(
          :session,
          team:,
          location:,
          academic_year:,
          dates: [Date.current],
          programmes: [Programme.flu]
        )
      end

      it "returns the existing session" do
        expect(call).to eq(existing_session)
      end

      it "doesn't create a new session" do
        expect { call }.not_to change(Session, :count)
      end

      it "adds the new programme type to the session" do
        expect { call }.to change {
          Session.find(existing_session.id).programme_types
        }.from(%w[flu]).to(%w[flu hpv])
      end
    end

    context "when specifying the date" do
      subject(:call) do
        described_class.call(
          team:,
          academic_year:,
          programme_type:,
          date: Date.tomorrow
        )
      end

      it "creates a new session for that date" do
        expect { call }.to change(Session, :count).by(1)

        session = Session.last
        expect(session.team_location.team).to eq(team)
        expect(session.team_location.academic_year).to eq(academic_year)
        expect(session.dates).to contain_exactly(Date.tomorrow)
        expect(session.programme_types).to contain_exactly(programme_type)
      end
    end
  end
end
