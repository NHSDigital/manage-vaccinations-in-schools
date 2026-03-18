# frozen_string_literal: true

class AppSessionButtonsComponent < ViewComponent::Base
  erb_template <<-ERB
    <div class="nhsuk-button-group">
      <% if policy(session).edit? %>
        <%= govuk_button_link_to "Edit session", edit_session_path(session), secondary: true %>

        <%= govuk_button_link_to "Download offline spreadsheet",
                                 session_path(session, format: :xlsx),
                                 secondary: true %>

        <% if policy(session).invite_to_clinic? %>
          <%= link_to "Send clinic invitations", edit_session_invite_to_clinic_path(@session) %>
        <% end %>
      <% end %>
    </div>
  ERB

  def initialize(session)
    @session = session
  end

  private

  attr_reader :session

  delegate :policy, :govuk_button_link_to, to: :helpers
end
