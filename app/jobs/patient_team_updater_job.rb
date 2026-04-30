# frozen_string_literal: true

class PatientTeamUpdaterJob < ApplicationJob
  sidekiq_options queue: :cache, lock: :until_executed

  def perform(patient_id = nil, team_id = nil)
    patient = (patient_id ? Patient.find(patient_id) : nil)
    team = (team_id ? Team.find(team_id) : nil)
    PatientTeamUpdater.call(patient:, team:)
  end
end
