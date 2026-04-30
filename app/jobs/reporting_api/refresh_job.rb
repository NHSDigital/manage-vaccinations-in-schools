# frozen_string_literal: true

class ReportingAPI::RefreshJob < ApplicationJobActiveJob
  def perform
    ReportingAPI::Total.refresh!
  end
end
