# frozen_string_literal: true

class ReportingAPI::RefreshJob < ApplicationJobSidekiq
  def perform = ReportingAPI::Total.refresh!
end
