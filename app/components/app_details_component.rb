# frozen_string_literal: true

class AppDetailsComponent < ViewComponent::Base
  erb_template <<-ERB
    <details id="<%= @id %>" class="nhsuk-details<%= expander_class %>"<%= open_attr %>>
      <summary class="nhsuk-details__summary" <%= sticky_class %>>
        <span class="nhsuk-details__summary-text">
          <%= summary %>
        </span>
      </summary>

      <div class="nhsuk-details__text">
        <%= content %>
      </div>
    </details>
  ERB

  renders_one :summary

  def initialize(
    summary: nil,
    open: false,
    expander: false,
    sticky: false,
    id: nil
  )
    with_summary { summary } if summary
    @open = open
    @expander = expander
    @sticky = sticky
    @id = id
  end

  def open_attr
    return unless @open

    " open"
  end

  def expander_class
    return unless @expander

    " nhsuk-expander"
  end

  def sticky_class
    return unless @sticky

    " data-module=app-sticky"
  end
end
