# frozen_string_literal: true

class AppImportReviewComponent < ViewComponent::Base
  include Pagy::Backend

  def initialize(
    import:,
    inter_team:,
    new_records:,
    auto_matched_records:,
    import_issues:,
    school_moves:,
    skipped_school_moves: [],
    open_sections: []
  )
    @import = import
    @inter_team = inter_team.sort_by(&:row_number)
    @inter_team_import_issues =
      @inter_team.select { it.record_type == "import_issue" }
    @new_records_pagy, @new_records = new_records
    @auto_matched_records_pagy, @auto_matched_records = auto_matched_records
    @import_issues_pagy, @import_issues = import_issues
    @school_moves_pagy, @school_moves = school_moves
    @school_moves_from_file = @school_moves.reject { it.row_number.nil? }
    @skipped_school_moves = skipped_school_moves.sort_by(&:row_number)
    @open_sections = open_sections
  end

  private

  def new_records_message
    count = @new_records_pagy.count
    "This upload includes #{pluralize(count, "new record")} that " \
      "#{count > 1 ? "are" : "is"} not currently in Mavis. " \
      "If you approve the upload, " \
      "#{count > 1 ? "these records" : "this record"} will be added to Mavis."
  end

  def auto_matched_message
    count = @auto_matched_records_pagy.count
    "This upload includes #{pluralize(count, "record")} that already " \
      "#{count > 1 ? "exist" : "exists"} in Mavis. " \
      "You do not need to remove #{count > 1 ? "these" : "this"} from your CSV file. " \
      "If you approve the upload, any additional information will be added to " \
      "the existing #{count > 1 ? "records" : "record"}."
  end

  def import_issues_message
    count = @import_issues_pagy.count
    "This upload includes #{pluralize(count, "record")} that " \
      "#{count > 1 ? "are close matches to existing records" : "is a close match to an existing record"} " \
      "in Mavis. If you approve the upload, you will need to resolve " \
      "#{count > 1 ? "these records" : "this record"} in the Issues tab."
  end

  def inter_team_message
    count = @inter_team.count
    "This upload includes #{count > 1 ? "children" : "child"} who " \
      "#{count > 1 ? "are" : "is"} currently registered with another team. " \
      "If you approve the upload, you will need to resolve #{count > 1 ? "these records" : "this record"} " \
      "in the School moves area of Mavis."
  end

  def school_moves_message
    count = @school_moves_pagy.count
    if @import.is_a?(ClassImport)
      "This upload will change the school of the #{count > 1 ? "children" : "child"} listed below. " \
        "Children present in the class list will be moved into the school, and those who are not in the " \
        "class list will be moved out of the school. If you approve the upload, you will need to resolve " \
        "#{count > 1 ? "these records" : "this record"} in the School moves area of Mavis."
    else
      "This upload includes #{count} #{count > 1 ? "children" : "child"} with a different school to " \
        "the one on their Mavis record. If you approve the upload, you will need to resolve " \
        "#{count > 1 ? "these records" : "this record"} in the School moves area of Mavis."
    end
  end

  def skipped_school_moves_message
    count = @skipped_school_moves.count
    "#{count} #{count > 1 ? "children" : "child"} #{count > 1 ? "are" : "is"} already " \
      "registered at a school in another team's area. #{count > 1 ? "These children" : "This child"} " \
      "#{count > 1 ? "remain" : "remains"} at their current school."
  end

  def show_cancel_button?
    @new_records_pagy.count.positive? ||
      @auto_matched_records_pagy.count.positive? ||
      @import_issues_pagy.count.positive? || @school_moves_from_file.any?
  end

  def cancel_button_text
    @import.in_re_review? ? "Ignore changes" : "Cancel and delete upload"
  end

  def approve_button_text
    if @import.in_re_review?
      "Approve and import changed records"
    else
      "Approve and import records"
    end
  end
end
