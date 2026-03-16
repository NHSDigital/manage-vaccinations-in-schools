# frozen_string_literal: true

class MavisFormBuilder < GOVUKDesignSystemFormBuilder::FormBuilder
  alias_method :_govuk_error_summary, :govuk_error_summary

  def mavis_error_summary(inline: false, **)
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
end
