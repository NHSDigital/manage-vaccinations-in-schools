# frozen_string_literal: true

# == Schema Information
#
# Table name: exports
#
#  id              :bigint           not null, primary key
#  exportable_type :string           not null
#  file_data       :binary
#  file_type       :string           not null
#  filename        :string           not null
#  status          :string           default("pending"), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  exportable_id   :bigint           not null
#  team_id         :bigint           not null
#  user_id         :bigint           not null
#
# Indexes
#
#  index_exports_on_created_at  (created_at)
#  index_exports_on_exportable  (exportable_type,exportable_id)
#  index_exports_on_status      (status)
#  index_exports_on_team_id     (team_id)
#
# Foreign Keys
#
#  fk_rails_...  (team_id => teams.id)
#  fk_rails_...  (user_id => users.id)
#
FactoryBot.define do
  factory :export do
    transient do
      exportable { create(Export.exportable_types.sample.underscore.to_sym) }
    end

    team { association(:team, :with_one_nurse) }
    user { team.users.first }
    status { :pending }
    exportable_type { exportable.class.name }
    exportable_id { exportable.id }
    file_type { exportable.file_type.to_s }
    filename { exportable.filename }

    trait :ready do
      status { :ready }
      file_data { "fake data" }
    end

    trait :failed do
      status { :failed }
    end

    trait :expired do
      status { :expired }
      file_data { nil }
    end
  end
end
