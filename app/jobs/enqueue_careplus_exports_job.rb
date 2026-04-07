# frozen_string_literal: true

class EnqueueCareplusExportsJob < ApplicationJob
  queue_as :careplus

  def perform
    Team.find_each do |team|
      unless team.careplus_enabled? && team.careplus_namespace.present? &&
               team.careplus_username.present? &&
               team.careplus_password.present?
        next
      end

      SendCareplusExportJob.perform_later(team.id)
    end
  end
end
