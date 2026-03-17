# frozen_string_literal: true

class AppSessionVaccinationsComponent < ViewComponent::Base
  erb_template <<-ERB
    <%= render AppCardComponent.new do |card| %>
      <% card.with_heading(level: 3) { "Vaccinations given in this session" } %>

      <%= govuk_table(html_attributes: { class: "nhsuk-table-responsive" }) do |table| %>
        <% table.with_head do |head| %>
          <% head.with_row do |row| %>
            <% row.with_cell(text: "Session date") %>
            <% session_column_names.each do |column| %>
              <% row.with_cell(text: column, numeric: true) %>
            <% end %>
          <% end %>
        <% end %>

        <% table.with_body do |body| %>
          <% rows.each_with_index do |row_data| %>
            <% body.with_row(first_cell_is_header: true) do |row| %>
              <% row.with_cell(text: row_data[:label]) %>
              <% row_data[:tallies].each do |tally| %>
                <% row.with_cell(text: tally.to_s, numeric: true) %>
              <% end %>
            <% end %>
          <% end %>
        <% end %>
      <% end %>
    <% end %>
  ERB

  def initialize(session)
    @session = session
  end

  def render? = session.started?

  private

  attr_reader :session

  delegate :programmes, to: :session

  delegate :govuk_table, to: :helpers

  def session_column_names
    @session_column_names ||=
      programmes.flat_map do |programme|
        if programme.has_multiple_vaccine_methods?
          base_name = programme.name_in_sentence.titlecase
          ["#{base_name} (nasal spray)", "#{base_name} (injection)"]
        else
          programme.name_in_sentence
        end
      end
  end

  def rows = session_dates_rows + [total_row]

  def session_dates_rows
    @session_dates_rows ||=
      session.dates.map do |date|
        {
          label: date.strftime("%e %B %Y"),
          tallies: tally_vaccination_counts_for_date(date)
        }
      end
  end

  def total_row
    { label: "Total", tallies: compute_total_tallies }
  end

  def tally_vaccination_counts_for_date(date)
    programmes.flat_map do |programme|
      vaccination_records_for_date =
        vaccination_records_by_date(programme).fetch(date, [])

      if programme.has_multiple_vaccine_methods?
        count_by_vaccine_method(vaccination_records_for_date)
      else
        [vaccination_records_for_date.count]
      end
    end
  end

  def count_by_vaccine_method(vaccination_records)
    nasal_spray_count =
      vaccination_records.count(&:delivery_method_nasal_spray?)
    injection_count = vaccination_records.count(&:delivery_method_injection?)
    [nasal_spray_count, injection_count]
  end

  def compute_total_tallies
    totals = Array.new(session_column_names.length, 0)

    session_dates_rows.each do |row|
      row[:tallies].each_with_index { |tally, index| totals[index] += tally }
    end

    totals
  end

  def vaccination_records_by_date(programme)
    @vaccination_records_by_date ||= {}
    @vaccination_records_by_date[programme.type] ||= VaccinationRecord
      .administered
      .kept
      .for_programme(programme)
      .where(session:, patient_id: patients_for_programme(programme))
      .group_by { |record| record.performed_at.to_date }
  end

  def patients_for_programme(programme)
    @patients_for_programme ||= {}
    @patients_for_programme[
      programme.type
    ] ||= session.patients.appear_in_programmes([programme], session:)
  end
end
