# frozen_string_literal: true

class AppImportStatusComponent < ViewComponent::Base
  def initialize(import:, break_tag: false)
    @import = import
    @break_tag = break_tag
  end

  private

  delegate :govuk_tag, to: :helpers

  def status_text
    {
      "pending_import" => "Processing",
      "rows_are_invalid" => "Invalid",
      "changesets_are_invalid" => "Failed",
      "in_review" => "Review and approve",
      "calculating_re_review" => "Processing",
      "in_re_review" => "Review",
      "committing" => "Importing",
      "processed" => "Completed",
      "removing_parent_relationships" => "Completed",
      "removing_vaccination_records" => "Completed",
      "partially_processed" => "Partially completed",
      "low_pds_match_rate" => "Failed",
      "cancelled" => "Cancelled"
    }.fetch(@import.status)
  end

  def status_color
    {
      "pending_import" => "blue",
      "rows_are_invalid" => "red",
      "changesets_are_invalid" => "red",
      "in_review" => "blue",
      "calculating_re_review" => "blue",
      "in_re_review" => "blue",
      "committing" => "blue",
      "processed" => "green",
      "removing_parent_relationships" => "green",
      "removing_vaccination_records" => "green",
      "partially_processed" => "green",
      "low_pds_match_rate" => "red",
      "cancelled" => "grey"
    }.fetch(@import.status)
  end
end
