# frozen_string_literal: true

class AppCreateNoteComponent < ViewComponent::Base
  erb_template <<-ERB
    <%= render AppDetailsComponent.new(summary: "Add a note", open:, expander: true) do %>
      <%= form_with model: note, url:, builder: do |f| %>
        <%= f.mavis_error_summary %>

        <%= f.govuk_text_area :body, label: { text: "Note" } %>
        <%= f.govuk_submit "Save note", class: "nhsuk-u-margin-bottom-0" %>
      <% end %>
    <% end %>
  ERB

  def initialize(note, open: false)
    @note = note
    @open = open
  end

  private

  attr_reader :note, :open

  delegate :patient, :session, to: :note

  def url = session_patient_activity_path(session, patient)

  def builder = GOVUKDesignSystemFormBuilder::FormBuilder
end
