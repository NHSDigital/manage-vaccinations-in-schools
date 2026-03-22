# frozen_string_literal: true

# == Schema Information
#
# Table name: notify_log_entries
#
#  id              :bigint           not null, primary key
#  body            :text
#  delivery_status :integer          default("sending"), not null
#  purpose         :integer
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
#  fk_rails_...  (patient_id => patients.id)
#  fk_rails_...  (sent_by_user_id => users.id)
#
FactoryBot.define do
  factory :notify_log_entry do
    transient { programme_types { [] } }

    patient

    trait :email do
      type { "email" }
      recipient { Faker::Internet.email }
      template_id { NotifyTemplate.all_ids(channel: :email).sample }
    end

    trait :sms do
      type { "sms" }
      recipient { Faker::PhoneNumber.phone_number }
      template_id { NotifyTemplate.all_ids(channel: :sms).sample }
    end

    delivery_id { SecureRandom.uuid }
    traits_for_enum :delivery_status
    traits_for_enum :purpose

    after(:build) do |notify_log_entry, evaluator|
      if notify_log_entry.notify_log_entry_programmes.empty?
        evaluator.programme_types.each do |type|
          patient = notify_log_entry.patient
          notify_log_entry.notify_log_entry_programmes.build(
            programme_type: type,
            disease_types: Programme.find(type, patient:).disease_types
          )
        end
      end
    end
  end
end
