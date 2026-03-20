# frozen_string_literal: true

# == Schema Information
#
# Table name: team_locations
#
#  id            :bigint           not null, primary key
#  academic_year :integer          not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  location_id   :bigint           not null
#  subteam_id    :bigint
#  team_id       :bigint           not null
#
# Indexes
#
#  idx_on_team_id_academic_year_location_id_1717f14a0c  (team_id,academic_year,location_id) UNIQUE
#  index_team_locations_on_location_id                  (location_id)
#  index_team_locations_on_subteam_id                   (subteam_id)
#  index_team_locations_on_team_id                      (team_id)
#
# Foreign Keys
#
#  fk_rails_...  (location_id => locations.id)
#  fk_rails_...  (subteam_id => subteams.id)
#  fk_rails_...  (team_id => teams.id)
#

class TeamLocation < ApplicationRecord
  audited associated_with: :team
  has_associated_audits

  belongs_to :team
  belongs_to :location
  belongs_to :subteam, optional: true

  has_many :consent_forms
  has_many :consent_notifications
  has_many :sessions

  has_many :patient_locations,
           ->(team_location) do
             where(academic_year: team_location.academic_year)
           end,
           through: :location

  validate :subteam_belongs_to_team

  scope :ordered, -> { order(created_at: :desc) }

  def email = subteam&.email || team&.email

  def name = subteam&.name || team&.name

  def phone = subteam&.phone || team&.phone

  def phone_instructions =
    subteam&.phone_instructions || team&.phone_instructions

  def safe_to_destroy?
    !sessions.exists? && !consent_forms.exists? && !patient_locations.exists?
  end

  private

  def subteam_belongs_to_team
    errors.add(:subteam, :inclusion) if subteam && subteam.team_id != team.id
  end
end
