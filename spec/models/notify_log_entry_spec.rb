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
describe NotifyLogEntry do
  subject(:notify_log_entry) { build(:notify_log_entry, type) }

  context "with an email type" do
    let(:type) { :email }

    it { should be_valid }
    it { should validate_presence_of(:purpose) }
    it { should allow_value(:consent_request).for(:purpose) }
  end

  context "with an SMS type" do
    let(:type) { :sms }

    it { should be_valid }
  end

  describe "#title" do
    subject(:title) { notify_log_entry.title }

    context "with a known template" do
      let(:notify_log_entry) do
        build(
          :notify_log_entry,
          :email,
          template_id:
            NotifyTemplate.find(:consent_clinic_request, channel: :email).id
        )
      end

      it { should eq("Consent clinic request") }
    end

    context "with an unknown template" do
      let(:notify_log_entry) do
        build(:notify_log_entry, :sms, template_id: SecureRandom.uuid)
      end

      it { should eq("Unknown SMS") }
    end

    context "with a template no longer in use" do
      let(:notify_log_entry) do
        build(
          :notify_log_entry,
          :email,
          template_id: "25473aa7-2d7c-4d1d-b0c6-2ac492f737c3"
        )
      end

      it { should eq("Consent confirmation given") }
    end
  end
end
