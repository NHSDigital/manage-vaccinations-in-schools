# frozen_string_literal: true

describe AppPatientProgrammeSessionsComponent do
  subject { render_inline(component) }

  let(:component) do
    described_class.new(patient, programme, academic_year:, team:)
  end

  let(:programme) { Programme.hpv }
  let(:academic_year) { AcademicYear.current }
  let(:team) { create(:team) }

  context "without a session" do
    let(:patient) { create(:patient) }

    it { should have_content("No sessions") }
  end

  context "with one session" do
    let(:programmes) { [Programme.hpv, Programme.mmr, Programme.flu] }

    let(:location) do
      create(
        :gias_school,
        name: "Waterloo Road",
        programmes:,
        academic_year: 2024
      )
    end
    let(:session) do
      create(
        :session,
        team:,
        location:,
        programmes:,
        date: Date.new(2025, 1, 1)
      )
    end

    # Can't use year_group here because we need an absolute date, not one
    # relative to the current academic year.
    let(:patient) { create(:patient, date_of_birth: Date.new(2009, 9, 1)) }

    before { create_list(:patient_location, 1, patient:, session:) }

    it { should have_link("Waterloo Road") }
    it { should have_content("1 January 2025") }

    context "with an ineligible programme type" do
      let(:patient) { create(:patient, date_of_birth: Date.new(2017, 9, 1)) }

      it { should have_content("No sessions") }
      it { should_not have_link("Waterloo Road") }
      it { should_not have_content("1 January 2025") }
    end

    context "with multiple sessions" do
      let(:other_location) do
        create(
          :gias_school,
          name: "Paddington Road",
          programmes: other_programmes,
          academic_year: 2024
        )
      end
      let(:other_session) do
        create(
          :session,
          team:,
          location: other_location,
          programmes: other_programmes,
          date: Date.new(2025, 2, 1)
        )
      end
      let(:other_programmes) do
        [Programme.hpv, Programme.flu, Programme.menacwy]
      end

      before do
        create(:patient_location, patient:, session: other_session)
        create(
          :vaccination_record,
          patient:,
          session:,
          outcome: :administered,
          performed_at_date: 1.month.ago,
          programme:
        )
        create(
          :vaccination_record,
          patient:,
          session:,
          outcome: :refused,
          performed_at_date: 1.year.ago,
          programme:
        )
      end

      it { should have_link("Waterloo Road") }
      it { should have_content("1 January 2025") }
      it { should have_content("Vaccinated") }

      it { should have_link("Paddington Road") }
      it { should have_content("1 February 2025") }
      it { should have_content("No outcome") }

      context "with a programme type filter that matches only one session" do
        let(:component) do
          described_class.new(patient, Programme.menacwy, academic_year:, team:)
        end

        it { should_not have_link("Waterloo Road") }
        it { should have_link("Paddington Road") }
      end
    end
  end
end
