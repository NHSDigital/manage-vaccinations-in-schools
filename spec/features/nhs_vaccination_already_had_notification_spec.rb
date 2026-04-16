# frozen_string_literal: true

describe "NHS vaccination already had notification" do
  before do
    Flipper.enable(:imms_api_integration)
    Flipper.enable(:imms_api_search_job, Programme.flu)
  end

  after do
    Flipper.disable(:imms_api_integration)
    Flipper.disable(:imms_api_search_job)
  end

  scenario "parent is notified when NHS API reveals their child was vaccinated elsewhere" do
    given_a_patient_with_consent_exists
    and_the_nhs_api_returns_a_flu_vaccination_for_the_patient
    when_the_nhs_vaccination_search_runs
    then_the_parent_receives_a_vaccination_already_had_email
  end

  private

  def given_a_patient_with_consent_exists
    team =
      create(
        :team,
        programmes: [Programme.flu],
        name: "South Hampshire SAIS",
        email: "southhampshire@example.com",
        phone: "02380 654321"
      )
    school = create(:gias_school, team:)
    session =
      create(:session, programmes: [Programme.flu], team:, location: school)
    @parent = create(:parent, email: "parent@example.com")
    @patient =
      create(
        :patient,
        nhs_number: "9449308357",
        parents: [@parent],
        session:,
        school:
      )
    create(
      :consent,
      :given,
      patient: @patient,
      programme: Programme.flu,
      parent: @parent
    )
  end

  def and_the_nhs_api_returns_a_flu_vaccination_for_the_patient
    stub_request(
      :get,
      "https://sandbox.api.service.nhs.uk/immunisation-fhir-api/FHIR/R4/Immunization"
    ).with(
      query: {
        "patient.identifier" => "https://fhir.nhs.uk/Id/nhs-number|9449308357",
        "-immunization.target" => "3IN1,FLU,HPV,MENACWY,MMR,MMRV"
      }
    ).to_return(
      status: 200,
      body:
        file_fixture(
          "fhir/search_responses/1_result_in_academic_year_2025.json"
        ).read,
      headers: {
        "content-type" => "application/fhir+json"
      }
    )
  end

  def when_the_nhs_vaccination_search_runs
    SearchVaccinationRecordsInNHSJob.new.perform(@patient.id)
  end

  def then_the_parent_receives_a_vaccination_already_had_email
    expect(email_deliveries).to include(
      matching_notify_email(
        to: "parent@example.com",
        template: :vaccination_already_had
      ).with_content_including(
        "South Hampshire SAIS",
        "southhampshire@example.com",
        "023 8065 4321"
      )
    )
  end
end
