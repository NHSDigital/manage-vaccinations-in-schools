# frozen_string_literal: true

class AppSearchResultsComponent < ViewComponent::Base
  erb_template <<-ERB
    <h2 class="nhsuk-heading-m nhsuk-u-margin-bottom-2"><%= heading %></h2>

    <p class="nhsuk-caption-m nhsuk-u-margin-bottom-4">
      <% if has_results? %>
        Showing <b><%= pagy.from %></b> to <b><%= pagy.to %></b> of <b><%= pagy.count %></b> <%= label %>
      <% elsif @no_results_text %>
        <%= @no_results_text %>
      <% else %>
        No <%= label %> matching search criteria found
      <% end %>
    </p>

    <%= content %>

    <% if has_results? %>
      <%= render AppPaginationComponent.new(pagy: @pagy) %>
    <% end %>
  ERB

  def initialize(pagy, label:, heading: "Search results", no_results_text: nil)
    @pagy = pagy
    @label = label
    @heading = heading
    @no_results_text = no_results_text
  end

  private

  attr_reader :pagy, :label, :heading

  def has_results? = pagy.count.positive?
end
