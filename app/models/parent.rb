# frozen_string_literal: true

# == Schema Information
#
# Table name: parents
#
#  id                           :bigint           not null, primary key
#  contact_method_other_details :text
#  contact_method_type          :string
#  email                        :string
#  full_name                    :string
#  phone                        :string
#  phone_receive_updates        :boolean          default(FALSE), not null
#  created_at                   :datetime         not null
#  updated_at                   :datetime         not null
#
# Indexes
#
#  index_parents_on_email  (email)
#
class Parent < ApplicationRecord
  audited

  before_save :reset_unused_attributes

  has_many :consents
  has_many :notify_log_entries, dependent: :nullify
  has_many :parent_relationships

  has_and_belongs_to_many :class_imports
  has_and_belongs_to_many :cohort_imports

  has_many :patients, through: :parent_relationships

  enum :contact_method_type,
       { any: "any", other: "other", text: "text", voice: "voice" },
       prefix: :contact_method,
       validate: {
         allow_nil: true
       }

  encrypts :email, :full_name, :phone, deterministic: true
  encrypts :contact_method_other_details

  normalizes :email, with: EmailAddressNormaliser.new
  normalizes :phone, with: PhoneNumberNormaliser.new

  validates :phone,
            presence: {
              if: :phone_receive_updates
            },
            phone: {
              allow_blank: true
            }
  validates :email, notify_safe_email: { allow_blank: true }
  validates :contact_method_other_details,
            :email,
            :full_name,
            :phone,
            length: {
              maximum: 300
            }
  validates :contact_method_other_details,
            presence: true,
            if: :contact_method_other?

  def self.match_existing(patient:, email:, phone:, full_name:)
    if email.present? && (parent = Parent.find_by(email:))
      return parent
    end

    return unless patient

    # We don't match on phone numbers or names globally as they can be re-used.

    if phone.present? && (parent = patient.parents.find_by(phone:))
      return parent
    end

    if full_name.present? && (parent = patient.parents.find_by(full_name:))
      parent
    end
  end

  def contactable?
    email.present? || phone.present?
  end

  def label
    full_name.presence || "Parent or guardian (name unknown)"
  end

  def contact_label
    [email, phone].compact_blank.join(" / ")
  end

  def contact_method_description
    if contact_method_other?
      "Other – #{contact_method_other_details}"
    else
      human_enum_name(:contact_method_type)
    end
  end

  def email_delivery_status
    most_recent_notify_log_entry(:email, recipient: email)&.delivery_status
  end

  def sms_delivery_status
    most_recent_notify_log_entry(:sms, recipient: phone)&.delivery_status
  end

  private

  def reset_unused_attributes
    self.contact_method_type = nil if phone.blank?
    self.contact_method_other_details = nil unless contact_method_other?
  end

  def most_recent_notify_log_entry(type, recipient:)
    return nil if recipient.blank?
    notify_log_entries.order(created_at: :desc).find_by(type:, recipient:)
  end
end
