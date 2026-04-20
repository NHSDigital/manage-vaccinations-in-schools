# frozen_string_literal: true

# == Schema Information
#
# Table name: cohort_imports
#
#  id                           :bigint           not null, primary key
#  academic_year                :integer          not null
#  changed_record_count         :integer
#  csv_data                     :text
#  csv_filename                 :text
#  csv_removed_at               :datetime
#  exact_duplicate_record_count :integer
#  new_record_count             :integer
#  processed_at                 :datetime
#  reviewed_at                  :datetime         default([]), not null, is an Array
#  reviewed_by_user_ids         :bigint           default([]), not null, is an Array
#  rows_count                   :integer
#  serialized_errors            :jsonb
#  status                       :integer          default("pending_import"), not null
#  created_at                   :datetime         not null
#  updated_at                   :datetime         not null
#  team_id                      :bigint           not null
#  uploaded_by_user_id          :bigint           not null
#
# Indexes
#
#  index_cohort_imports_on_team_id              (team_id)
#  index_cohort_imports_on_uploaded_by_user_id  (uploaded_by_user_id)
#
# Foreign Keys
#
#  fk_rails_...  (team_id => teams.id)
#  fk_rails_...  (uploaded_by_user_id => users.id)
#
FactoryBot.define do
  factory :cohort_import do
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
      "CHILD_FIRST_NAME,CHILD_LAST_NAME,CHILD_DATE_OF_BIRTH\nJohn,Smith,2010-01-01\n"
    end
    csv_filename { csv_data && Faker::File.file_name(ext: "csv") }
    rows_count { csv_data ? csv_data.lines.count - 1 : nil }

    academic_year { AcademicYear.pending }

    after(:build) do |import, evaluator|
      if evaluator.uploaded_csv_file.present?
        file = evaluator.uploaded_csv_file
        import.csv =
          ActionDispatch::Http::UploadedFile.new(
            tempfile: File.open(file.path, "rb"),
            filename: evaluator.uploaded_csv_file.original_filename,
            type: evaluator.uploaded_csv_file.content_type || "text/csv"
          )
      end
    end

    trait :csv_removed do
      csv_data { nil }
      csv_filename { Faker::File.file_name(ext: "csv") }
      csv_removed_at { Time.zone.now }
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

      changed_record_count { 0 }
      exact_duplicate_record_count { 0 }
      new_record_count { 0 }
    end
  end
end
