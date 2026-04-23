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
FactoryBot.define do
  factory :careplus_report_vaccination_record do
    careplus_report
    vaccination_record
    change_type { :created }
  end
end
