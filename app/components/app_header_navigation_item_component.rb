# frozen_string_literal: true

class AppHeaderNavigationItemComponent < ViewComponent::Base
  def initialize(title, path, request_path:, count: nil)
    @title = title
    @path = path
    @request_path = request_path
    @count = count
  end

  def call
    tag.li(class: classes) do
      link_to(
        @path,
        class: "nhsuk-header__navigation-link",
        aria: {
          current: current? ? "page" : nil
        }
      ) { safe_join([@title, count_tag].compact) }
    end
  end

  def current?
    @request_path.starts_with?(@path)
  end

  def classes
    [
      "nhsuk-header__navigation-item",
      ("nhsuk-header__navigation-item--current" if current?),
      ("app-header__navigation-item--with-count" if show_count?)
    ].compact.join(" ")
  end

  def show_count?
    @count != nil
  end

  def count_tag
    render AppCountComponent.new(@count) if show_count?
  end
end
