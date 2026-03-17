# frozen_string_literal: true

class AppTimestampedEntryComponent < ViewComponent::Base
  erb_template <<-ERB
    <p>
      <%= @text %>
    </p>
    <p class="nhsuk-u-margin-bottom-2 nhsuk-u-secondary-text-colour nhsuk-u-font-size-16 nhsuk-u-margin-bottom-0">
      <% if @recorded_by.present? %>
        <%= mail_to(@recorded_by.email, @recorded_by.full_name) %>,
      <% end %>
      <%= @timestamp.to_fs(:long) %>
    </p>
  ERB

  def initialize(text:, timestamp:, recorded_by: nil)
    @text = text
    @timestamp = timestamp || Time.zone.now
    @recorded_by = recorded_by
  end
end
