# frozen_string_literal: true

# == Schema Information
#
# Table name: school_move_log_entries
#
#  id            :bigint           not null, primary key
#  home_educated :boolean
#  created_at    :datetime         not null
#  patient_id    :bigint           not null
#  school_id     :bigint
#  team_id       :bigint
#  user_id       :bigint
#
# Indexes
#
#  index_school_move_log_entries_on_patient_id  (patient_id)
#  index_school_move_log_entries_on_school_id   (school_id)
#  index_school_move_log_entries_on_team_id     (team_id)
#  index_school_move_log_entries_on_user_id     (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (patient_id => patients.id) ON DELETE => cascade
#  fk_rails_...  (school_id => locations.id)
#  fk_rails_...  (team_id => teams.id)
#  fk_rails_...  (user_id => users.id)
#
class SchoolMoveLogEntry < ApplicationRecord
  belongs_to :patient
  belongs_to :school, class_name: "Location", optional: true
  belongs_to :team, optional: true
  belongs_to :user, optional: true

  validates :school,
            presence: {
              if: -> { home_educated.nil? }
            },
            absence: {
              unless: -> { home_educated.nil? }
            }

  validates :home_educated, inclusion: { in: :valid_home_educated_values }

  validate :school_is_correct_type

  def valid_home_educated_values
    school.nil? ? [true, false] : [nil]
  end

  def school_is_correct_type
    location = school
    if location && !(location.school? || location.generic_school?)
      errors.add(:school, "must be a school location type")
    end
  end
end
