# frozen_string_literal: true

class AppImportReviewPaginatedRecordsSummaryComponent < AppImportReviewRecordsSummaryComponent
  erb_template <<-ERB
    <%= helpers.govuk_table(
      html_attributes: {
        class: "nhsuk-table-responsive"
      }
    ) do |table| %>
      <% table.with_head do |head| %>
        <% head.with_row do |row| %>
          <% row.with_cell(text: "CSV file row") %>
          <% row.with_cell(text: "Name and NHS number") %>
          <% row.with_cell(text: "Date of birth") %>
          <% row.with_cell(text: "Postcode") %>
          <% row.with_cell(text: "Year group") %>
        <% end %>
      <% end %>

      <% table.with_body do |body| %>
        <% changesets.each do |changeset| %>
          <% body.with_row do |row| %>
            <% row.with_cell do %>
              <%= changeset.row_number ? changeset.csv_row_number.to_s : "" %>
            <% end %>
            <% row.with_cell do %>
              <span class="nhsuk-table-responsive__heading">Name and NHS number</span>
              <span><%= format_name(changeset) %></span>
              <br>
              <span class="nhsuk-u-secondary-text-colour nhsuk-u-font-size-16">
                <%= format_nhs_number(changeset) %>
              </span>
            <% end %>

            <% row.with_cell do %>
              <span class="nhsuk-table-responsive__heading">Date of birth</span>
              <span><%= format_date_of_birth(changeset) %></span>
            <% end %>

            <% row.with_cell do %>
              <span class="nhsuk-table-responsive__heading">Postcode</span>
              <span><%= changeset.address_postcode %></span>
            <% end %>

            <% row.with_cell do %>
              <span class="nhsuk-table-responsive__heading">Year group</span>
              <span><%= format_year_group_for_changeset(changeset) %></span>
            <% end %>
          <% end %>
        <% end %>
      <% end %>
    <% end %>
    <%= render AppPaginationComponent.new(pagy: @pagy, anchor: @anchor) if has_results? %>
  ERB

  def initialize(pagy:, records:, anchor: nil)
    @changesets = records || []
    @pagy = pagy
    @anchor = anchor
  end

  def has_results? = @pagy.count.positive?
end
