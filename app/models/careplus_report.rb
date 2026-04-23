# frozen_string_literal: true

# == Schema Information
#
# Table name: careplus_reports
#
#  id              :bigint           not null, primary key
#  academic_year   :integer          not null
#  csv_data        :text
#  csv_filename    :text
#  csv_removed_at  :datetime
#  date_from       :date             not null
#  date_to         :date             not null
#  programme_types :enum             not null, is an Array
#  scheduled_at    :datetime         not null
#  sent_at         :datetime
#  status          :integer          default("pending"), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  team_id         :bigint           not null
#
# Indexes
#
#  index_careplus_reports_on_programme_types            (programme_types) USING gin
#  index_careplus_reports_on_status_and_scheduled_at    (status,scheduled_at)
#  index_careplus_reports_on_team_id                    (team_id)
#  index_careplus_reports_on_team_id_and_academic_year  (team_id,academic_year)
#
# Foreign Keys
#
#  fk_rails_...  (team_id => teams.id)
#
class CareplusReport < ApplicationRecord
  include HasManyProgrammes

  audited associated_with: :team

  belongs_to :team

  has_many :careplus_report_vaccination_records, dependent: :destroy
  has_many :vaccination_records, through: :careplus_report_vaccination_records

  enum :status, { pending: 0, sending: 1, sent: 2, failed: 3 }, validate: true

  validates :academic_year, :scheduled_at, presence: true
  validates :date_from, :date_to, presence: true
  validates :programme_types, presence: true
  validates :date_to,
            comparison: {
              greater_than_or_equal_to: :date_from
            },
            if: -> { date_from.present? && date_to.present? }

  scope :for_academic_year, ->(year) { where(academic_year: year) }
  scope :pending_send, -> { pending.where(scheduled_at: ..Time.current) }
end
