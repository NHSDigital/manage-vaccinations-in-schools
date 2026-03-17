# frozen_string_literal: true

class AppPatientProgrammeSessionTableComponent < ViewComponent::Base
  erb_template <<-ERB
    <% if sessions.any? %>
      <%= govuk_table(html_attributes: { class: "nhsuk-table-responsive" }) do |table| %>
        <% table.with_head do |head| %>
          <% head.with_row do |row| %>
            <% row.with_cell(text: "Location") %>
            <% row.with_cell(text: "Session dates") %>
            <% row.with_cell(text: "Session outcome") %>
          <% end %>
        <% end %>

        <% table.with_body do |body| %>
          <% sessions.each do |session| %>
            <% body.with_row do |row| %>
              <% row.with_cell do %>
                <span class="nhsuk-table-responsive__heading">Location</span>
                <%= link_to session.location.name,
                            session_patient_programme_path(session, patient, programme_type) %>
              <% end %>

              <% row.with_cell do %>
                <span class="nhsuk-table-responsive__heading">Session dates</span>
                <ul class="nhsuk-list">
                  <% session.dates.each do |date| %>
                    <li><%= date.to_fs(:long) %></li>
                  <% end %>
                </ul>
              <% end %>

              <% row.with_cell do %>
                <span class="nhsuk-table-responsive__heading">Session outcome</span>
                <%= session_outcome_tag(session, programme_type) %>
              <% end %>
            <% end %>
          <% end %>
        <% end %>
      <% end %>
    <% else %>
      <p>No sessions</p>
    <% end %>
  ERB

  def initialize(patient, current_team:, programme_type:)
    @patient = patient
    @current_team = current_team
    @programme_type = programme_type
  end

  private

  attr_reader :patient, :current_team, :programme_type

  delegate :govuk_table, to: :helpers

  def sessions
    @sessions ||=
      patient
        .sessions
        .where(session_programme_year_groups: { programme_type: })
        .for_team(current_team)
        .includes(:location, :session_programme_year_groups)
  end

  def session_outcome_tag(session, programme_type)
    vaccination_record =
      session
        .vaccination_records
        .where(programme_type:, patient:)
        .order(:performed_at_date, :performed_at_time)
        .last
    return "No outcome" unless vaccination_record

    helpers.vaccination_record_status_tag(vaccination_record)
  end
end
