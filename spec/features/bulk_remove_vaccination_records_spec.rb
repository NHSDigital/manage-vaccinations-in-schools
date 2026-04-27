# frozen_string_literal: true

describe "Bulk remove vaccination records" do
  before do
    given_i_am_signed_in
    and_the_feature_is_enabled
  end

  scenario "Removes exclusive records and unlinks shared records" do
    when_i_do_the_first_import
    and_i_do_the_second_import

    when_i_go_to_the_page_for_the_first_import
    and_i_click_remove_all_vaccination_records_from_import
    then_i_see_the_confirmation_page
    and_i_see_1_record_will_be_deleted
    and_i_see_1_record_will_be_unlinked

    when_i_click_remove_all_vaccination_records
    then_i_see_the_success_flash
    and_i_am_on_the_completed_imports_tab

    when_i_go_to_the_page_for_the_first_import
    then_i_see_the_removal_in_progress_message

    when_the_bulk_remove_job_is_processed
    then_the_exclusive_record_is_deleted
    and_the_shared_record_is_unlinked_but_not_deleted
    and_i_no_longer_see_the_removal_in_progress_message
  end

  def given_i_am_signed_in
    programme = Programme.hpv
    @team =
      create(:team, :with_one_nurse, ods_code: "R1L", programmes: [programme])
    create(:gias_school, urn: "110158")
    sign_in @team.users.first
  end

  def and_the_feature_is_enabled
    Flipper.enable(:import_bulk_remove_vaccination_records)
  end

  def upload_vaccination_records(fixture_filename)
    visit imports_path
    click_on "Upload records"
    choose "Vaccination records"
    click_on "Continue"
    attach_file_fixture "immunisation_import[csv]",
                        "immunisation_import/point_of_care/#{fixture_filename}"
    click_on "Continue"
    wait_for_import_to_complete(ImmunisationImport)
  end

  def when_i_do_the_first_import
    upload_vaccination_records("bulk_remove_two_records.csv")
    @first_import = ImmunisationImport.order(:created_at).last
  end

  def and_i_do_the_second_import
    upload_vaccination_records("bulk_remove_one_record.csv")
    @second_import = ImmunisationImport.order(:created_at).last
    @exclusive_record =
      @first_import
        .vaccination_records
        .where.not(id: @second_import.vaccination_record_ids)
        .first
    @shared_record =
      @first_import
        .vaccination_records
        .where(id: @second_import.vaccination_record_ids)
        .first
  end

  def when_i_go_to_the_page_for_the_first_import
    visit immunisation_import_path(@first_import)
  end

  def and_i_click_remove_all_vaccination_records_from_import
    click_on "Remove all vaccination records from import"
  end

  def then_i_see_the_confirmation_page
    expect(page).to have_content(
      "Are you sure you want to remove all vaccination records included in this import?"
    )
  end

  def and_i_see_1_record_will_be_deleted
    expect(page).to have_content(
      "This will permanently delete 1 vaccination record that is only linked to this import."
    )
  end

  def and_i_see_1_record_will_be_unlinked
    expect(page).to have_content(
      "1 record that is linked to other imports will be unlinked from this import but not deleted."
    )
  end

  def when_i_click_remove_all_vaccination_records
    click_on "Remove all vaccination records"
  end

  def then_i_see_the_success_flash
    expect(page).to have_content(
      "All vaccination records included in this import are being removed."
    )
  end

  def and_i_am_on_the_completed_imports_tab
    expect(page).to have_css("td.nhsuk-table__cell", text: "Completed")
  end

  def then_i_see_the_removal_in_progress_message
    expect(page).to have_content(
      "Vaccination records are currently being removed from this import"
    )
  end

  def when_the_bulk_remove_job_is_processed
    perform_enqueued_jobs(only: BulkRemoveVaccinationRecordsJob)
  end

  def then_the_exclusive_record_is_deleted
    expect { @exclusive_record.reload }.to raise_error(
      ActiveRecord::RecordNotFound
    )
  end

  def and_the_shared_record_is_unlinked_but_not_deleted
    expect { @shared_record.reload }.not_to raise_error
    expect(@first_import.vaccination_records.reload).not_to include(
      @shared_record
    )
    expect(@second_import.vaccination_records.reload).to include(@shared_record)
  end

  def and_i_no_longer_see_the_removal_in_progress_message
    page.refresh
    expect(page).not_to have_content(
      "Vaccination records are currently being removed from this import"
    )
  end
end
