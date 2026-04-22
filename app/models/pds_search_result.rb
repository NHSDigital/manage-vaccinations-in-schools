# frozen_string_literal: true

# == Schema Information
#
# Table name: pds_search_results
#
#  id          :bigint           not null, primary key
#  import_type :string
#  nhs_number  :string
#  result      :integer          not null
#  step        :integer          not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  import_id   :bigint
#  patient_id  :bigint           not null
#
# Indexes
#
#  index_pds_search_results_on_import      (import_type,import_id)
#  index_pds_search_results_on_patient_id  (patient_id)
#
# Foreign Keys
#
#  fk_rails_...  (patient_id => patients.id) ON DELETE => cascade
#
class PDSSearchResult < ApplicationRecord
  belongs_to :patient
  belongs_to :import, polymorphic: true, optional: true

  enum :step,
       {
         no_fuzzy_with_history: 0,
         no_fuzzy_with_history_daily: 1,
         no_fuzzy_without_history: 2,
         no_fuzzy_with_wildcard_postcode: 3,
         no_fuzzy_with_wildcard_given_name: 4,
         no_fuzzy_with_wildcard_family_name: 5,
         fuzzy: 6
       },
       validate: true

  enum :result,
       {
         no_matches: 0,
         one_match: 1,
         too_many_matches: 2,
         error: 3,
         skip_step: 4,
         no_postcode: 5
       },
       validate: true

  def self.grouped_sets
    records = all.to_a
    grouped_records =
      records.group_by do |record|
        if record.import_id.present?
          [:import, record.import_type, record.import_id]
        else
          [:date, record.created_at.to_date]
        end
      end
    grouped_records.values
  end

  def self.latest_set
    grouped_sets.max_by { |set| set.map(&:created_at).max }
  end

  def pds_nhs_number
    changeset&.pds_nhs_number
  end

  def changeset
    return unless import_id

    PatientChangeset.find_by(
      import_type: import_type,
      import_id: import_id,
      patient_id: patient_id
    )
  end

  def timeline_item
    {
      is_past_item: true,
      heading_text: human_enum_name(:step),
      description:
        I18n.t(
          "activerecord.attributes.#{self.class.model_name.i18n_key}.results.#{result}",
          nhs_number: nhs_number
        )
    }
  end
end
