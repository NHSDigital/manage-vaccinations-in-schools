# frozen_string_literal: true

# == Schema Information
#
# Table name: parent_relationships
#
#  id                           :bigint           not null, primary key
#  contact_method_other_details :text
#  contact_method_type          :string
#  email                        :string
#  full_name                    :string
#  other_name                   :string
#  phone                        :string
#  phone_receive_updates        :string
#  type                         :string           not null
#  created_at                   :datetime         not null
#  updated_at                   :datetime         not null
#  parent_id                    :bigint           not null
#  patient_id                   :bigint           not null
#
# Indexes
#
#  index_parent_relationships_on_parent_id_and_patient_id  (parent_id,patient_id) UNIQUE
#  index_parent_relationships_on_patient_id                (patient_id)
#
# Foreign Keys
#
#  fk_rails_...  (parent_id => parents.id)
#  fk_rails_...  (patient_id => patients.id)
#
FactoryBot.define do
  factory :parent_relationship do
    patient
    parent { association :parent, family_name: patient.family_name }

    type { %w[father guardian mother other].sample }
    other_name { type == "other" ? "Other" : nil }

    traits_for_enum :type

    trait :granddad do
      type { "other" }
      other_name { "Granddad" }
    end
  end
end
