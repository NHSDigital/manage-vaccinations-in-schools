# frozen_string_literal: true

# == Schema Information
#
# Table name: notify_log_entries
#
#  id              :bigint           not null, primary key
#  body            :text
#  delivery_status :integer          default("sending"), not null
#  purpose         :integer          not null
#  recipient       :string           not null
#  subject         :text
#  type            :integer          not null
#  created_at      :datetime         not null
#  consent_form_id :bigint
#  delivery_id     :uuid
#  parent_id       :bigint
#  patient_id      :bigint
#  sent_by_user_id :bigint
#  template_id     :uuid             not null
#
# Indexes
#
#  index_notify_log_entries_on_consent_form_id  (consent_form_id)
#  index_notify_log_entries_on_delivery_id      (delivery_id)
#  index_notify_log_entries_on_parent_id        (parent_id)
#  index_notify_log_entries_on_patient_id       (patient_id)
#  index_notify_log_entries_on_sent_by_user_id  (sent_by_user_id)
#
# Foreign Keys
#
#  fk_rails_...  (consent_form_id => consent_forms.id)
#  fk_rails_...  (parent_id => parents.id) ON DELETE => nullify
#  fk_rails_...  (patient_id => patients.id) ON DELETE => cascade
#  fk_rails_...  (sent_by_user_id => users.id)
#
class NotifyLogEntry < ApplicationRecord
  include Sendable

  self.inheritance_column = nil

  belongs_to :consent_form, optional: true
  belongs_to :patient, optional: true
  belongs_to :parent, optional: true

  has_one :team_location, through: :consent_form

  has_many :notify_log_entry_programmes,
           class_name: "NotifyLogEntry::Programme",
           inverse_of: :notify_log_entry,
           dependent: :destroy

  enum :type, { email: 0, sms: 1 }, validate: true
  enum :delivery_status,
       {
         sending: 0,
         delivered: 1,
         permanent_failure: 2,
         temporary_failure: 3,
         technical_failure: 4,
         not_uk_mobile_number_failure: 5
       }

  enum :purpose,
       {
         consent_request: 0,
         consent_reminder: 1,
         consent_confirmation: 2,
         consent_warning: 3,
         clinic_invitation: 4,
         session_reminder: 5,
         triage_vaccination_will_happen: 6,
         triage_vaccination_wont_happen: 7,
         triage_vaccination_at_clinic: 8,
         triage_delay_vaccination: 9,
         vaccination_administered: 10,
         vaccination_already_had: 11,
         vaccination_not_administered: 12,
         vaccination_deleted: 13,
         consent_confirmation_given: 14,
         consent_confirmation_refused: 15,
         consent_confirmation_given_triage: 16,
         consent_confirmation_given_clinic: 17,
         clinic_initial_invitation: 18,
         clinic_subsequent_invitation: 19,
         triage_vaccination_will_happen_second_dose: 20
       }

  validates :purpose, presence: true
  validates :recipient, presence: true
  validates :template_id, presence: true

  scope :for_programme_type,
        ->(programme_type) do
          where(
            NotifyLogEntry::Programme
              .select("1")
              .where("notify_log_entry_id = notify_log_entries.id")
              .where(programme_type:)
              .arel
              .exists
          )
        end

  scope :for_session,
        ->(session) { for_programme_type(session.programme_types) }

  encrypts :recipient, deterministic: true
  encrypts :subject, :body

  accepts_nested_attributes_for :notify_log_entry_programmes

  def programmes = notify_log_entry_programmes.map(&:programme)
end
