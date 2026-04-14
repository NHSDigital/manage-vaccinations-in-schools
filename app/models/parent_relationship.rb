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
class ParentRelationship < ApplicationRecord
  audited associated_with: :patient

  self.inheritance_column = nil

  belongs_to :parent
  belongs_to :patient

  has_and_belongs_to_many :class_imports
  has_and_belongs_to_many :cohort_imports

  enum :type,
       {
         father: "father",
         guardian: "guardian",
         mother: "mother",
         other: "other",
         unknown: "unknown"
       },
       validate: true

  encrypts :other_name

  validates :other_name, presence: true, length: { maximum: 300 }, if: :other?

  before_validation -> { self.other_name = nil unless other? }

  accepts_nested_attributes_for :parent
  validates_associated :parent

  def label
    other? ? "Other – #{other_name}" : human_enum_name(:type).capitalize
  end

  def label_with_parent
    unknown? ? parent.label : "#{parent.label} (#{label.downcase_first})"
  end

  def ordinal_label
    index = patient.parent_relationships.find_index(self)

    if index.nil?
      "parent or guardian"
    elsif index <= 10
      "#{I18n.t(index + 1, scope: :ordinal_number)} parent or guardian"
    else
      "#{index.ordinalize} parent or guardian"
    end
  end
end
