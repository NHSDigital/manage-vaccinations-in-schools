# frozen_string_literal: true

class PatientArchiver
  def initialize(patient:, team:, type:, other_details: nil, user: nil)
    @patient = patient
    @team = team
    @type = type
    @other_details = other_details
    @user = user
  end

  def call
    ActiveRecord::Base.transaction do
      archive_reason.type = type
      archive_reason.other_details = type == "other" ? other_details : ""
      archive_reason.save!

      patient.clear_pending_sessions!(team:)

      destroy_school_moves!

      update_patient_teams!
    end
  end

  def self.call(...) = new(...).call

  private_class_method :new

  private

  attr_reader :patient, :team, :type, :other_details, :user

  def archive_reason
    @archive_reason ||= ArchiveReason.new(team:, patient:, created_by: user)
  end

  def destroy_school_moves!
    patient
      .school_moves
      .joins_team_locations
      .where("team_locations.team_id = ?", team.id)
      .destroy_all
  end

  def update_patient_teams!
    PatientTeamUpdater.call(patient:, team:)
  end
end
