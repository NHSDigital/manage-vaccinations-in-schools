# frozen_string_literal: true

class AppCreateNoteComponent < ViewComponent::Base
  erb_template <<-ERB
    <%= render AppDetailsComponent.new(summary:, open:, expander: true) do %>
      <%= form_with model: note, url:, builder: do |f| %>
        <%= f.mavis_error_summary %>

        <%= f.govuk_text_area :body,
                              label: { text: "Note" },
                              hint: { text: "Notes are visible to all users, and cannot be edited or deleted" } %>
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

  def url
    if (session_id = note.session&.id)
      patient_note_path(note.patient, session_id:)
    else
      patient_note_path(note.patient)
    end
  end

  def summary
    note.session ? "Add a session note" : "Add a note to this record"
  end

  def builder = MavisFormBuilder
end
