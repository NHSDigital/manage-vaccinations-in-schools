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
FactoryBot.define do
  factory :careplus_report do
    transient { programmes { [Programme.sample] } }

    team { association(:team, programmes:) }
    programme_types { programmes.map(&:type) }
    academic_year { AcademicYear.current }
    date_from { Date.current.beginning_of_month }
    date_to { Date.current.end_of_month }
    scheduled_at { Time.current }

    trait :sent do
      status { :sent }
      sent_at { Time.current }
      csv_filename { "careplus_report.csv" }
      csv_data { "col1,col2\nval1,val2" }
    end

    trait :failed do
      status { :failed }
    end
  end
end
