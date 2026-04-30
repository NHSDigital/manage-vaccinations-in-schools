# frozen_string_literal: true

describe "Patient invalidation deletes vaccination record from API", :pds do
  around { |example| travel_to(Date.new(2025, 8, 7)) { example.run } }

  scenario "PDS check invalidates patient and deletes vaccination record from API" do
    given_a_patient_has_a_vaccination_record_eligible_for_api
    and_the_feature_flags_are_enabled
    and_the_vaccination_record_has_been_sent_to_the_api

    when_a_pds_check_is_completed_which_returns_that_the_patient_is_invalid

    then_the_patient_has_been_invalidated
    and_the_vaccination_record_is_deleted_from_the_api
  end

  def given_a_patient_has_a_vaccination_record_eligible_for_api
    @programme = Programme.hpv
    @team = create(:team, :with_one_nurse, programmes: [@programme])
    @session =
      create(:session, :scheduled, team: @team, programmes: [@programme])
    @patient = create(:patient, session: @session, nhs_number: "9000000009")

    @vaccination_record =
      create(
        :vaccination_record,
        :administered,
        patient: @patient,
        programme: @programme,
        session: @session,
        notify_parents: true
      )
  end

  def and_the_feature_flags_are_enabled
    Flipper.enable(:imms_api_sync_job, @programme)
    Flipper.enable(:imms_api_integration)
  end

  def and_the_vaccination_record_has_been_sent_to_the_api
    @immunisation_uuid = Random.uuid

    @stubbed_post_request =
      stub_immunisations_api_post(uuid: @immunisation_uuid)

    @vaccination_record.sync_to_nhs_immunisations_api!
    Sidekiq::Job.drain_all

    expect(@stubbed_post_request).to have_been_requested

    @vaccination_record.reload
    expect(@vaccination_record.nhs_immunisations_api_id).to be_present
    expect(@vaccination_record.nhs_immunisations_api_synced_at).to be_present
  end

  def when_a_pds_check_is_completed_which_returns_that_the_patient_is_invalid
    # Move time forward to ensure deletion sync happens after the initial sync
    travel_to(1.hour.from_now)

    stub_pds_search_to_return_no_patients
    stub_pds_get_nhs_number_to_return_an_invalidated_patient

    PatientUpdateFromPDSJob.new.perform(@patient, [])
  end

  def then_the_patient_has_been_invalidated
    @patient.reload
    expect(@patient).to be_invalidated
    expect(@patient.invalidated_at).to be_present
  end

  def and_the_vaccination_record_is_deleted_from_the_api
    @stubbed_delete_request =
      stub_immunisations_api_delete(uuid: @immunisation_uuid)

    Sidekiq::Job.drain_all

    expect(@stubbed_delete_request).to have_been_requested
  end
end
