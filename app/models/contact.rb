# frozen_string_literal: true

# == Schema Information
#
# Table name: contacts
#
#  id                      :bigint           not null, primary key
#  contact_method          :enum             not null
#  email                   :string
#  full_name               :string           not null
#  phone                   :string
#  phone_receive_updates   :boolean          default(FALSE), not null
#  relationship            :enum             not null
#  relationship_other_name :string
#  source                  :enum             not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  patient_id              :bigint           not null
#
# Indexes
#
#  index_contacts_on_patient_id            (patient_id)
#  index_contacts_on_patient_id_and_email  (patient_id,email) UNIQUE
#  index_contacts_on_patient_id_and_phone  (patient_id,phone) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (patient_id => patients.id)
#

class Contact < ApplicationRecord
  belongs_to :patient

  validates :full_name, presence: true
  validates :relationship, presence: true
  validates :source, presence: true
  validates :contact_method, presence: true

  validates :email, notify_safe_email: { allow_blank: true }

  validates :email, uniqueness: { scope: :patient_id }, allow_blank: true
  validates :phone, uniqueness: { scope: :patient_id }, allow_blank: true

  validates :phone, presence: { if: -> { phone? } }
  validates :email, presence: { if: -> { email? } }

  encrypts :email, :full_name, :phone, deterministic: true

  normalizes :email, with: EmailAddressNormaliser.new
  normalizes :phone, with: PhoneNumberNormaliser.new

  enum :contact_method, { phone: "phone", email: "email" }
  enum :relationship,
       {
         father: "father",
         guardian: "guardian",
         mother: "mother",
         other: "other",
         unknown: "unknown"
       }
  enum :source,
       {
         child_record: "child_record",
         class_list: "class_list",
         consent_response: "consent_response",
         sais: "sais"
       }

  def label
    full_name.presence || "Parent or guardian (name unknown)"
  end
end
