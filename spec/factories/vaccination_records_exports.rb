# frozen_string_literal: true

# == Schema Information
#
# Table name: vaccination_records_exports
#
#  id             :bigint           not null, primary key
#  academic_year  :integer          not null
#  date_from      :date
#  date_to        :date
#  file_format    :string           not null
#  programme_type :string           not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
FactoryBot.define do
  factory :vaccination_records_export do
    programme_type { Programme::TYPES.sample }
    academic_year { AcademicYear.current }
    file_format { "mavis" }
  end
end
