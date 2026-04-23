# frozen_string_literal: true

# == Schema Information
#
# Table name: careplus_report_vaccination_records
#
#  change_type           :integer          not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  careplus_report_id    :bigint           not null, primary key
#  vaccination_record_id :bigint           not null, primary key
#
# Indexes
#
#  idx_on_careplus_report_id_98876049c7     (careplus_report_id)
#  idx_on_vaccination_record_id_e7f05454ab  (vaccination_record_id)
#
# Foreign Keys
#
#  fk_rails_...  (careplus_report_id => careplus_reports.id) ON DELETE => cascade
#  fk_rails_...  (vaccination_record_id => vaccination_records.id)
#
class CareplusReportVaccinationRecord < ApplicationRecord
  self.primary_key = %i[careplus_report_id vaccination_record_id]

  belongs_to :careplus_report
  belongs_to :vaccination_record

  enum :change_type, { created: 0, updated: 1 }, validate: true
end
