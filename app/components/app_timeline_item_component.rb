# frozen_string_literal: true

class AppTimelineItemComponent < ViewComponent::Base
  erb_template <<-ERB
    <li class="app-timeline__item <%= 'app-timeline__item--past' if @is_past %>">
      <% if @is_active || @is_past %>
        <svg class="app-timeline__badge" aria-hidden="true" xmlns="http://www.w3.org/2000/svg" width="28" height="28" viewBox="0 0 28 28">
          <circle cx="14" cy="14" r="13" fill="#005EB8"/>
        </svg>
      <% else %>
        <svg class="app-timeline__badge app-timeline__badge--small" aria-hidden="true" xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 14 14">
          <circle cx="7" cy="7" r="6" fill="white" stroke="#AEB7BD" stroke-width="2"/>
        </svg>
      <% end %>

      <div class="app-timeline__content">
        <h<%= @heading_level %> class="app-timeline__header <%= 'nhsuk-u-font-weight-bold' if @is_active %>">
          <%= heading %>
        </h<%= @heading_level %>>

        <p class="app-timeline__description">
          <%= description %>
        </p>

        <%= content %>
      </div>
    </li>
  ERB

  renders_one :heading
  renders_one :description

  def initialize(is_active: false, is_past: false, heading_level: 3)
    @is_active = is_active
    @is_past = is_past
    @heading_level = heading_level
  end
end
