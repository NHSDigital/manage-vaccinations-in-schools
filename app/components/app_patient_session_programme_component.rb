# frozen_string_literal: true

class AppPatientSessionProgrammeComponent < ViewComponent::Base
  erb_template <<-ERB
    <%= render AppCardComponent.new(feature: true) do |card| %>
      <% card.with_heading(level: 4, colour:) { heading } %>
      <% if details.present? %>
        <p><%= details %></p>
      <% end %>
      <% if programme_status.vaccinated? || programme_status.cannot_vaccinate? %>
        <%= render AppPatientVaccinationTableComponent.new(
              patient,
              programme:,
              academic_year:,
              show_caption: true,
              show_details: false
            ) %>
      <% end %>
      <%= render AppActionLinkComponent.new(
            text: action_link_text,
            href: patient_programme_path(patient, programme.type)
          ) %>
    <% end %>
  ERB

  def initialize(patient:, session:, programme:)
    @patient = patient
    @session = session
    @programme = programme
  end

  private

  attr_reader :patient, :session, :programme

  delegate :academic_year, to: :session

  def heading
    "#{resolver[:prefix]}: #{resolver[:text]}"
  end

  def colour
    resolver[:colour]
  end

  def details
    case programme_status.status
    when /\Adue/
      criteria_label =
        I18n.t(
          programme_status.vaccine_criteria.to_param,
          scope: :vaccine_criteria
        )
      if criteria_label.present?
        "#{patient.given_name} is ready to vaccinate (#{criteria_label.downcase})."
      else
        "#{patient.given_name} is ready to vaccinate."
      end
    when /\Avaccinated/
      record =
        patient
          .vaccination_records
          .for_programme(programme)
          .order_by_performed_at
          .first
      nurse = [
        record&.performed_by_given_name,
        record&.performed_by_family_name
      ].compact_blank.join(" ")
      if nurse.present?
        "#{patient.given_name} was vaccinated by #{nurse} on #{record&.performed_at&.to_fs(:long)}."
      else
        "#{patient.given_name} was vaccinated on #{record&.performed_at&.to_fs(:long)}."
      end
    when "needs_triage"
      "You need to decide if it’s safe to vaccinate."
    else
      resolver[:details_text]
    end
  end

  def programme_status
    @programme_status ||= patient.programme_status(programme, academic_year:)
  end

  def action_link_text
    "View child’s #{programme.name} record"
  end

  def resolver
    @resolver ||=
      PatientProgrammeStatusResolver.call(
        patient,
        programme_type: programme.type,
        academic_year:
      )
  end
end
