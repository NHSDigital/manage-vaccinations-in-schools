# frozen_string_literal: true

# == Schema Information
#
# Table name: immunisation_imports
#
#  id                           :bigint           not null, primary key
#  changed_record_count         :integer
#  csv_data                     :text
#  csv_filename                 :text             not null
#  csv_removed_at               :datetime
#  exact_duplicate_record_count :integer
#  ignored_record_count         :integer
#  new_record_count             :integer
#  processed_at                 :datetime
#  rows_count                   :integer
#  serialized_errors            :jsonb
#  status                       :integer          default("pending_import"), not null
#  type                         :integer          not null
#  created_at                   :datetime         not null
#  updated_at                   :datetime         not null
#  team_id                      :bigint           not null
#  uploaded_by_user_id          :bigint           not null
#
# Indexes
#
#  index_immunisation_imports_on_team_id              (team_id)
#  index_immunisation_imports_on_uploaded_by_user_id  (uploaded_by_user_id)
#
# Foreign Keys
#
#  fk_rails_...  (team_id => teams.id)
#  fk_rails_...  (uploaded_by_user_id => users.id)
#
FactoryBot.define do
  factory :immunisation_import do
    transient do
      # Can be used by the caller to pass in a file that simulates how it would
      # come from the file upload field in the UI.
      uploaded_csv_file { nil }
    end

    team
    uploaded_by

    # Callers should use `csv_data` to set the CSV content, this is faster than
    # using `uploaded_csv_file`.
    csv_data do
      "VACCINATED,VACCINE_GIVEN,DATE_OF_VACCINATION\nY,Gardasil9,2024-01-01\n"
    end
    csv_filename { csv_data && Faker::File.file_name(ext: "csv") }
    rows_count { csv_data ? csv_data.lines.count - 1 : nil }

    type { team.type }

    after(:build) do |import, evaluator|
      if evaluator.uploaded_csv_file.present?
        import.csv =
          ActionDispatch::Http::UploadedFile.new(
            tempfile: File.open(evaluator.uploaded_csv_file.path, "rb"),
            filename: evaluator.uploaded_csv_file.original_filename,
            type: evaluator.uploaded_csv_file.content_type || "text/csv"
          )
      end
    end

    trait :csv_removed do
      after(:create, &:remove!)
    end

    trait :pending do
      status { :pending_import }
    end

    trait :invalid do
      serialized_errors { { "errors" => ["Error 1", "Error 2"] } }
      status { :rows_are_invalid }
    end

    trait :processed do
      processed_at { Time.current }
      status { :processed }

      ignored_record_count { 0 }
      changed_record_count { 0 }
      exact_duplicate_record_count { 0 }
      new_record_count { 0 }
    end
  end
end
