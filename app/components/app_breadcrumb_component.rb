# frozen_string_literal: true

class AppBreadcrumbComponent < ViewComponent::Base
  def initialize(items:, reverse: false, attributes: {})
    @items = items
    @reverse = reverse
    @attributes = attributes
  end

  private

  delegate :govuk_back_link, to: :helpers

  def linkable_items = @items.select { it[:href].present? }
end
