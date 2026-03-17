# frozen_string_literal: true

class AppWarningCalloutComponent < ViewComponent::Base
  erb_template <<-ERB
    <div class="nhsuk-card nhsuk-card--warning">
      <div class="nhsuk-card__content">
        <h<%= @level %> class="nhsuk-card__heading">
          <span role="text">
            <span class="nhsuk-u-visually-hidden">Important: </span>
            <%= @heading %>
          </span>
        </h<%= @level %>>

        <% if @description.present? %>
          <p><%= @description %></p>
        <% end %>

        <%= content %>
      </div>
    </div>
  ERB

  def initialize(heading:, description: nil, level: 3)
    @heading = heading
    @description = description
    @level = level
  end
end
