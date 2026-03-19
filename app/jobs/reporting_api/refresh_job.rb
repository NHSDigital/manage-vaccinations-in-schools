# frozen_string_literal: true

class ReportingAPI::RefreshJob < ApplicationJob
  def perform
    ReportingAPI::Total.refresh!
  end
end
