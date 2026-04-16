# frozen_string_literal: true

class AppTimelineComponent < ViewComponent::Base
  erb_template <<-ERB
    <ul class="app-timeline">
      <% @items.each do |item| %>
        <% next if item.blank? %>

        <% if item[:type] == :section_header %>
          <li>
            <h3 class="nhsuk-heading-s">
              <%= item[:date] %>
            </h3>
          </li>
        <% else %>
          <%= render AppTimelineItemComponent.new(is_active: item[:active], is_past: item[:is_past_item]) do %>
            <% it.with_heading { format_heading(item).html_safe } %>
            <% it.with_description { format_description(item).html_safe } %>
          <% end %>
        <% end %>
      <% end %>
    </ul>
  ERB

  def initialize(items)
    @items = items
  end

  def render? = @items.present?

  private

  EVENT_COLOUR_MAPPING = {
    "CohortImport" => "blue",
    "ClassImport" => "purple",
    "PatientSession" => "green",
    "Consent" => "yellow",
    "Triage" => "red",
    "VaccinationRecord" => "grey",
    "SchoolMove" => "orange",
    "SchoolMoveLogEntry" => "orange"
  }.freeze

  def format_heading(item)
    if item[:type] && item[:created_at]
      time = format_time(item[:created_at])
      event_tag =
        govuk_tag(
          text: item[:event_type],
          colour: tag_colour(item[:event_type])
        )
      "#{event_tag} at #{time}"
    elsif item[:heading_text]
      item[:heading_text]
    end
  end

  def format_description(item)
    if item[:details].present?
      formatted_details = format_event_details(item[:details])
      id_info =
        item[:id] ? "<p class=\"timeline__byline\">id: #{item[:id]}</p>" : ""
      "#{id_info}#{formatted_details}"
    elsif item[:description].present?
      item[:description]
    else
      ""
    end
  end

  def format_time(date_time)
    date_time.strftime("%H:%M:%S")
  end

  def format_event_details(details)
    return "" if details.blank?

    if details.is_a?(Hash)
      formatted =
        details.map do |key, value|
          if value.is_a?(Hash)
            nested =
              value.map do |sub_key, sub_value|
                nested_value =
                  sub_value.is_a?(String) ? sub_value : sub_value.inspect
                "<div style='margin-left: 1em;'><strong>#{sub_key}:</strong> #{nested_value}</div>"
              end
            "<div><strong>#{key}:</strong>#{nested.join}</div>"
          else
            "<div><strong>#{key}:</strong> #{value}</div>"
          end
        end
      formatted.join
    else
      details.to_s
    end
  end

  def tag_colour(type)
    return "light-blue" if type.end_with?("-Audit")
    EVENT_COLOUR_MAPPING.fetch(type, "grey")
  end

  def govuk_tag(text:, colour:)
    helpers.govuk_tag(text: text, colour: colour)
  end
end
