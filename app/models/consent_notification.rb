# frozen_string_literal: true

# == Schema Information
#
# Table name: consent_notifications
#
#  id               :bigint           not null, primary key
#  programme_types  :enum             not null, is an Array
#  sent_at          :datetime         not null
#  type             :integer          not null
#  patient_id       :bigint           not null
#  sent_by_user_id  :bigint
#  session_id       :bigint
#  team_location_id :bigint           not null
#
# Indexes
#
#  index_consent_notifications_on_patient_id        (patient_id)
#  index_consent_notifications_on_programme_types   (programme_types) USING gin
#  index_consent_notifications_on_sent_by_user_id   (sent_by_user_id)
#  index_consent_notifications_on_session_id        (session_id)
#  index_consent_notifications_on_team_location_id  (team_location_id)
#
# Foreign Keys
#
#  fk_rails_...  (patient_id => patients.id)
#  fk_rails_...  (sent_by_user_id => users.id)
#  fk_rails_...  (session_id => sessions.id)
#
class ConsentNotification < ApplicationRecord
  include HasManyProgrammes
  include Sendable

  self.inheritance_column = nil

  belongs_to :patient
  belongs_to :session, optional: true
  belongs_to :team_location

  has_one :team, through: :team_location

  scope :for_academic_year,
        ->(academic_year) do
          joins(:team_location).where(team_locations: { academic_year: })
        end

  enum :type,
       { request: 0, initial_reminder: 1, subsequent_reminder: 2 },
       validate: true

  scope :reminder, -> { initial_reminder.or(subsequent_reminder) }

  delegate :academic_year, to: :team_location

  def reminder? = initial_reminder? || subsequent_reminder?

  def sent_by_user? = sent_by != nil

  def sent_by_background_job? = sent_by.nil?

  def automated_reminder? = sent_by_background_job? && reminder?

  def manual_reminder? = sent_by_user? && reminder?
end
