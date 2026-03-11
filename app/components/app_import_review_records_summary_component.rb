# frozen_string_literal: true

class AppImportReviewRecordsSummaryComponent < ViewComponent::Base
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
              <span class="nhsuk-table-responsive__heading">CSV file row</span>
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
    <% if @pagy %>
      <%= render AppPaginationComponent.new(pagy: @pagy, anchor: @anchor) if has_results? %>
    <% end %>
  ERB

  def initialize(changesets: [], pagy: nil, anchor: nil)
    @changesets = (pagy ? changesets : changesets.sort_by(&:row_number))

    @pagy = pagy
    @anchor = anchor
  end

  private

  attr_reader :changesets

  def format_name(changeset)
    FullNameFormatter.call(changeset, context: :internal)
  end

  def format_nhs_number(changeset)
    helpers.format_nhs_number(changeset.nhs_number)
  end

  def format_date_of_birth(changeset)
    changeset.date_of_birth.to_date&.to_fs(:long)
  end

  def format_year_group_for_changeset(changeset)
    year_group =
      changeset.birth_academic_year.to_year_group(academic_year: 2025)
    helpers.format_year_group(year_group)
  end

  def has_results? = @pagy&.count&.positive?
end
