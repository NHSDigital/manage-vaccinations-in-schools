# frozen_string_literal: true

class AppCardComponent < ViewComponent::Base
  erb_template <<-ERB
    <<%= top_level_tag %> class="<%= card_classes %>">
      <% unless heading&.show_in_content? %>
        <%= heading %>
      <% end %>

      <div class="<%= content_classes %>">
        <% if heading&.show_in_content? %>
          <%= heading %>
        <% end %>

        <% if description.present? %>
          <p class="nhsuk-card__description"><%= description %></p>
        <% end %>

        <% if data.present? %>
          <p class="nhsuk-card__description app-card__data"><%= data %></p>
        <% end %>

        <% if meta.present? %>
          <p class="nhsuk-body-s"><%= meta %></p>
        <% end %>

        <%= content %>
      </div>
    </<%= top_level_tag %>>
  ERB

  renders_one :heading,
              ->(level: 3, size: nil, colour: nil, actions: []) do
                Heading.new(level:, size:, colour:, link_to: @link_to, actions:)
              end

  renders_one :description
  renders_one :data
  renders_one :meta

  def initialize(
    colour: nil,
    link_to: nil,
    clickable: nil,
    feature: false,
    secondary: false,
    compact: false,
    filters: false,
    section: false
  )
    @link_to = link_to
    @clickable = clickable.nil? ? link_to.present? : clickable
    @colour = colour
    @feature = filters || feature
    @secondary = secondary
    @compact = compact
    @filters = filters
    @section = section
  end

  private

  def top_level_tag = @section ? "section" : "div"

  def card_classes
    [
      "nhsuk-card",
      ("nhsuk-card--clickable" if @clickable),
      ("nhsuk-card--feature" if @feature),
      ("nhsuk-card--secondary" if @secondary),
      "app-card",
      ("app-card--compact" if @compact),
      ("app-card--#{@colour}" if @colour.present?),
      ("app-filters" if @filters)
    ].compact.join(" ")
  end

  def content_classes
    [
      "nhsuk-card__content",
      ("nhsuk-card__content--feature" if @feature),
      ("nhsuk-card__content--secondary" if @secondary)
    ].compact.join(" ")
  end
end
