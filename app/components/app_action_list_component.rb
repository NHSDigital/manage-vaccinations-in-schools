# frozen_string_literal: true

class AppActionListComponent < ViewComponent::Base
  renders_many :items, "Item"

  erb_template <<~ERB
    <% if items? %>
      <ul class="app-action-list">
        <% items.each do |item| %>
          <li class="app-action-list__item"><%= item %></li>
        <% end %>
      </ul>
    <% end %>
  ERB

  class Item < ViewComponent::Base
    def initialize(text: nil, href: nil, visually_hidden_text: nil)
      @text = html_escape(text)
      @href = href
      @visually_hidden_text = visually_hidden_text
    end

    def call
      label = content || @text
      if @visually_hidden_text.present?
        label =
          safe_join(
            [
              label,
              tag.span(
                " #{@visually_hidden_text}",
                class: "nhsuk-u-visually-hidden"
              )
            ]
          )
      end

      if @href.present?
        link_to(label, @href)
      elsif label.present?
        label
      else
        raise(ArgumentError, "no text or content")
      end
    end
  end
end
