# frozen_string_literal: true

class AppExportStatusComponent < ViewComponent::Base
  def initialize(export)
    @export = export
  end

  def call
    render AppStatusTagComponent.new(@export.status, context: :export)
  end
end
