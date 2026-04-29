# frozen_string_literal: true

module CareplusReportsHelper
  def careplus_report_status_tag(careplus_report)
    render AppStatusTagComponent.new(
             careplus_report.status,
             context: :careplus_report
           )
  end
end
