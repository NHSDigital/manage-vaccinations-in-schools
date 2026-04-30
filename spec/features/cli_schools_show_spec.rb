# frozen_string_literal: true

require_relative "../../app/lib/mavis_cli"

describe "mavis schools show" do
  before do
    # To ensure Rainbow doesn't insert escape codes into the output
    Rainbow.enabled = false
  end

  context "with just a URN" do
    it "displays the school details" do
      given_a_school_exists
      and_a_site_with_the_same_urn_exists
      when_i_run_the_command
      then_the_school_details_are_displayed
      and_the_programme_year_groups_are_displayed
      and_other_locations_with_the_same_urn_are_displayed
    end
  end

  context "with the --id option" do
    it "finds the school with the id" do
      given_a_school_exists
      when_i_run_the_command_with_the_id_option
      then_the_school_details_are_displayed
    end
  end

  context "with the --any-site option" do
    it "finds all the school sites with the URN" do
      given_a_school_with_sites_exists
      when_i_run_the_command_with_the_any_site_option
      then_the_school_details_with_sites_are_displayed
    end
  end

  context "with a team that has patients in a variety of states" do
    it "displays the school details" do
      given_a_school_exists
      and_the_school_has_patients_across_academic_years
      when_i_run_the_command_with_the_show_patients_option
      then_the_correct_patient_counts_are_displayed
    end
  end

  context "with a clinic" do
    it "finds the school with the id" do
      given_a_clinic_exists
      when_i_run_the_command_with_the_id_option
      then_the_clinic_details_are_displayed
    end
  end

  def given_a_school_exists
    team = create(:team, programme_types: %w[flu hpv])
    @school =
      create(
        :gias_school,
        name: "Test School",
        urn: "123456",
        team:
      ).tap do |location|
        location.import_year_groups_from_gias!(
          academic_year: AcademicYear.previous
        )

        location.import_default_programme_year_groups!(
          [Programme.flu],
          academic_year: AcademicYear.previous
        )
      end
  end

  def given_a_clinic_exists
    team = create(:team, programme_types: %w[flu hpv])
    @clinic =
      create(
        :location,
        :generic_clinic,
        name: "Test Clinic",
        team:
      ).tap do |location|
        location.import_year_groups_from_gias!(
          academic_year: AcademicYear.previous
        )

        location.import_default_programme_year_groups!(
          [Programme.flu],
          academic_year: AcademicYear.previous
        )
      end
  end

  def and_a_site_with_the_same_urn_exists
    @site =
      create(:gias_school, name: "Test School Site B", urn: "123456", site: "B")
  end

  def and_the_school_has_patients_across_academic_years
    location = school = @school
    session =
      create(
        :session,
        location:,
        team: @school.teams.first,
        programmes: [Programme.flu]
      )
    session_last_year =
      create(
        :session,
        location:,
        team: @school.teams.first,
        date: Date.new(AcademicYear.previous, 11, 1),
        programmes: [Programme.flu]
      )

    # patient in current academic years
    create(:patient, school: @school, location: @school)

    # patient in previous academic years
    create(:patient, academic_year: AcademicYear.previous, school:, location:)

    # patient in current and previous academic years
    create(
      :patient,
      :in_attendance,
      school:,
      location:,
      session:
    ).tap do |patient|
      create(
        :patient_location,
        patient:,
        school:,
        academic_year: AcademicYear.previous
      )
    end

    # patient with attendance record in previous academic year
    create(
      :patient,
      academic_year: AcademicYear.previous,
      school:,
      location:,
      session: session_last_year
    ).tap do |patient|
      create(
        :attendance_record,
        :present,
        patient:,
        session: session_last_year,
        date: session_last_year.dates.first
      )
    end

    # patient with gillick assessment in current academic year
    create(:patient, school:, location:, session:).tap do |patient|
      create(:gillick_assessment, :competent, patient:, session:)
    end

    # patient with gillick assessment record in previous academic year
    create(
      :patient,
      school:,
      location:,
      session: session_last_year
    ).tap do |patient|
      create(
        :gillick_assessment,
        :competent,
        patient:,
        session: session_last_year
      )
    end
  end

  def given_a_school_with_sites_exists
    @school = create(:gias_school, name: "Test School", urn: "123456")
    @site = create(:gias_school, name: "Site B", urn: "123456", site: "B")
  end

  def when_i_run_the_command
    @output =
      capture_output do
        Dry::CLI.new(MavisCLI).call(arguments: %w[schools show] + [@school.urn])
      end
  end

  def when_i_run_the_command_with_the_id_option
    id = @school&.id || @clinic.id
    @output =
      capture_output do
        Dry::CLI.new(MavisCLI).call(arguments: %w[schools show --id] + [id])
      end
  end

  def when_i_run_the_command_with_the_any_site_option
    @output =
      capture_output do
        Dry::CLI.new(MavisCLI).call(
          arguments: %w[schools show --any-site] + [@school.urn]
        )
      end
  end

  def when_i_run_the_command_with_the_show_patients_option
    @output =
      capture_output do
        Dry::CLI.new(MavisCLI).call(
          arguments: %w[schools show --show-patients] + [@school.urn]
        )
      end
  end

  def then_the_school_details_are_displayed
    expect(@output).to match(/name.*Test School/)
    expect(@output).to match(/urn.*123456/)
  end

  def then_the_school_details_with_sites_are_displayed
    expect(@output).to match(/name.*Test School/)
    expect(@output).to match(/urn.*123456/)
    expect(@output).to match(/site.*B/)
  end

  def and_the_programme_year_groups_are_displayed
    expect(@output).to match(
      /flu:\s*year groups: 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11/
    )
    expect(@output).to match(/hpv:\s*year groups: 8, 9, 10, 11/)
  end

  def and_other_locations_with_the_same_urn_are_displayed
    expect(@output).to match(/other locations with the same URN:/)
    expect(@output).to match(%r{  123456B: Test School Site B})
  end

  def then_the_correct_patient_counts_are_displayed
    expect(@output).to match(/^total patients: 7/)
    expect(@output).to match(/^  in current academic year: 3/)
    expect(@output).to match(/^    with attendance records: 1/)
    expect(@output).to match(/^    with gillick assessments: 1/)
  end

  def then_the_clinic_details_are_displayed
    expect(@output).to match(/name.*Test Clinic/)
    expect(@output).not_to include("other locations with the same URN")
  end
end
