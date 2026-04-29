# frozen_string_literal: true

class AppStatusComponent < ViewComponent::Base
  erb_template <<-ERB
    <p class="app-status app-status--<%= @colour %> <% if @small %>app-status--small<% end %> <%= @classes %>">
      <%= icon_svg %>
      <%= @text %>
    </p>
  ERB

  def initialize(
    text:,
    colour: "blue",
    icon: :warning,
    small: false,
    classes: ""
  )
    @text = text
    @colour = colour
    @icon = icon
    @small = small
    @classes = classes
  end

  private

  def icon_svg
    case @icon
    when :tick
      path = <<~PATH.squish
        M11.4 18.8a2 2 0 0 1-2.7.1h-.1L4 14.1a1.5 1.5 0 0 1 2.1-2L10 16l8.1-8.1a1.5 1.5 0 1 1
        2.2 2l-8.9 9Z
      PATH
      svg_icon("nhsuk-icon--tick", path)
    when :cross
      path = <<~PATH.squish
        M17 18.5c-.4 0-.8-.1-1.1-.4l-10-10c-.6-.6-.6-1.6 0-2.1.6-.6 1.5-.6 2.1 0l10 10c.6.6.6
        1.5 0 2.1-.3.3-.6.4-1 .4z M7 18.5c-.4 0-.8-.1-1.1-.4-.6-.6-.6-1.5 0-2.1l10-10c.6-.6
        1.5-.6 2.1 0 .6.6.6 1.5 0 2.1l-10 10c-.3.3-.6.4-1 .4z
      PATH
      svg_icon("nhsuk-icon--cross", path)
    when :warning
      path = <<~PATH.squish
        M12 2a10 10 0 1 1 0 20 10 10 0 0 1 0-20Zm0 14a1.5 1.5 0 1 0 0 3 1.5 1.5 0 0 0
        0-3Zm-1.5-9.5V13a1.5 1.5 0 0 0 3 0V6.5a1.5 1.5 0 0 0-3 0Z
      PATH
      svg_icon("nhsuk-icon--warning", path)
    else
      raise ArgumentError,
            "Unknown icon: #{@icon.inspect}. Must be :warning, :tick, or :cross"
    end
  end

  def svg_icon(icon_class, path)
    tag.svg(
      class: "nhsuk-icon #{icon_class}",
      xmlns: "http://www.w3.org/2000/svg",
      viewBox: "0 0 24 24",
      width: "16",
      height: "16",
      focusable: "false",
      aria: {
        hidden: "true"
      }
    ) { tag.path(d: path) }
  end
end
