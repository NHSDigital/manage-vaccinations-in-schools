# frozen_string_literal: true

class MavisFormBuilder < GOVUKDesignSystemFormBuilder::FormBuilder
  alias_method :_govuk_error_summary, :govuk_error_summary

  RAILS_DEFAULT_MESSAGES =
    I18n.t("errors.messages").values.select { _1.is_a?(String) }.freeze

  def mavis_error_summary(inline: false, **)
    check_for_default_error_messages if Rails.env.local?

    summary = _govuk_error_summary(**)
    @template.content_for(:error_summary_rendered, "true")

    if inline
      summary
    else
      @template.content_for(:before_content) { summary }
      nil
    end
  end

  def govuk_error_summary(*, **)
    raise "Use f.mavis_error_summary instead of f.govuk_error_summary. " \
            "Default places the summary in content_for(:before_content). " \
            "Pass inline: true to render it inline."
  end

  private

  def check_for_default_error_messages
    return if object.nil? || object.errors.none?

    defaults = object.errors.select { it.message.in?(RAILS_DEFAULT_MESSAGES) }

    return if defaults.empty?

    details = defaults.map { |e| "#{e.attribute}: \"#{e.message}\"" }.join(", ")

    raise "Default Rails error messages found: #{details}. " \
            "Add custom messages to your validations."
  end
end
