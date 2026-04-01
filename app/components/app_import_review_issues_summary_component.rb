# frozen_string_literal: true

class AppImportReviewIssuesSummaryComponent < ViewComponent::Base
  erb_template <<-ERB
    <%= helpers.govuk_table(
      html_attributes: {
        class: "nhsuk-table-responsive"
      }
    ) do |table| %>
      <% table.with_head do |head| %>
        <% head.with_row do |row| %>
          <% row.with_cell(text: "CSV file row") if review_screen %>
          <% row.with_cell(text: "Name and NHS number") %>
          <% row.with_cell(text: "Issue to review") %>
          <% row.with_cell(text: "Actions") unless review_screen %>
        <% end %>
      <% end %>
      <% table.with_body do |body| %>
        <% records.each do |record| %>
          <% body.with_row do |row| %>
            <% if review_screen %>
              <% row.with_cell do %>
                <span class="nhsuk-table-responsive__heading">CSV file row</span>
                <span><%= record.csv_row_number.to_s %></span>
              <% end %>
            <% end %>

            <% row.with_cell do %>
              <span class="nhsuk-table-responsive__heading">Name and NHS number</span>
              <span><%= format_name(record) %></span>
              <br>
              <span class="nhsuk-u-secondary-text-colour nhsuk-u-font-size-16">
                <%= format_nhs_number(record) %>
              </span>
            <% end %>

            <% row.with_cell do %>
              <span class="nhsuk-table-responsive__heading">Issue to review</span>
              <span><%= determine_issue_text(record) %></span>
            <% end %>

            <% unless review_screen %>
              <% row.with_cell do %>
                <span class="nhsuk-table-responsive__heading">Actions</span>
                <%= generate_action_link(record) %>
              <% end %>
            <% end %>
          <% end %>
        <% end %>
      <% end %>
    <% end %>
    <% if @pagy %>
      <%= render AppPaginationComponent.new(pagy: @pagy, anchor: @anchor) if has_results? %>
    <% end %>
  ERB

  def initialize(
    import: nil,
    records: nil,
    pagy: nil,
    anchor: nil,
    review_screen: true
  )
    @import = import
    @review_screen = review_screen
    @records =
      (pagy ? records : Array(records).sort_by { it.try(:row_number) || 0 })
    @pagy = pagy
    @anchor = anchor
  end

  private

  attr_reader :import, :records, :review_screen

  def format_name(record)
    case record
    when Patient
      record.full_name
    when VaccinationRecord, PatientChangeset
      record.patient&.full_name || "Unknown"
    else
      raise "Unknown record type: #{record.class.name}"
    end
  end

  def format_nhs_number(record)
    nhs_number =
      case record
      when Patient
        record.nhs_number
      when VaccinationRecord, PatientChangeset
        record.patient&.nhs_number
      else
        raise "Unknown record type: #{record.class.name}"
      end

    helpers.format_nhs_number(nhs_number)
  end

  def determine_issue_text(record)
    case record
    when PatientChangeset, Patient
      patient_import_issue_text(record)
    when VaccinationRecord
      "Imported record closely matches an existing record. Review and confirm."
    else
      raise "Unknown record type: #{record.class.name}"
    end
  end

  def patient_import_issue_text(record)
    pending_changes = record.pending_changes || {}
    issue_groups = helpers.issue_categories_for(pending_changes.keys)

    if issue_groups.any? && matched_on_nhs_number?(record)
      "Matched on NHS number. " \
        "#{issue_groups.to_sentence.capitalize} #{issue_groups.size == 1 ? "does not" : "do not"} match."
    else
      "Possible match found. Review and confirm."
    end
  end

  def matched_on_nhs_number?(record)
    if record.is_a?(PatientChangeset)
      record.matched_on_nhs_number?
    elsif record.is_a?(Patient)
      import&.changesets&.find_by(patient_id: record.id)&.matched_on_nhs_number?
    end
  end

  def generate_action_link(record)
    case record
    when Patient
      review_link(record, "patient")
    when VaccinationRecord
      review_link(record, "vaccination-record")
    else
      ""
    end
  end

  def review_link(record, type)
    full_name =
      record.is_a?(Patient) ? record.full_name : record.patient&.full_name

    helpers.link_to(
      imports_issue_path(record, type:, return_to: url_for(import))
    ) do
      helpers.safe_join(
        ["Review ", tag.span(full_name, class: "nhsuk-u-visually-hidden")]
      )
    end
  end

  def has_results? = @pagy&.count&.positive?
end
