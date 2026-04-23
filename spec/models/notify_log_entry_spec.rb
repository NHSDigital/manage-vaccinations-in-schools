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
#  fk_rails_...  (patient_id => patients.id) ON DELETE => cascade
#  fk_rails_...  (sent_by_user_id => users.id)
#
describe NotifyLogEntry do
  subject(:notify_log_entry) { build(:notify_log_entry, type) }

  context "with an email type" do
    let(:type) { :email }

    it { should be_valid }
  end

  context "with an SMS type" do
    let(:type) { :sms }

    it { should be_valid }
  end

  describe ".purpose_for_template_name" do
    subject(:purpose) do
      described_class.purpose_for_template_name(template_name)
    end

    context "when the template indicates a consent request" do
      let(:template_name) { :consent_school_request }

      it { should eq(:consent_request) }
    end

    context "when the template indicates a consent reminder" do
      let(:template_name) { :consent_school_reminder }

      it { should eq(:consent_reminder) }
    end

    context "when the template indicates a consent confirmation" do
      let(:template_name) { :consent_confirmation_given }

      it { should eq(:consent_confirmation) }
    end

    context "when the template indicates a consent warning" do
      let(:template_name) { :consent_unknown_contact_details_warning }

      it { should eq(:consent_warning) }
    end

    context "when the template indicates a clinic invitation" do
      let(:template_name) { :clinic_flu_invitation }

      it { should eq(:clinic_invitation) }
    end

    context "when the template indicates a session reminder" do
      let(:template_name) { :session_school_reminder_today }

      it { should eq(:session_reminder) }
    end

    context "when the template indicates triage vaccination will happen" do
      let(:template_name) { :triage_vaccination_will_happen_outcome }

      it { should eq(:triage_vaccination_will_happen) }
    end

    context "when the template indicates triage vaccination won't happen" do
      let(:template_name) { :triage_vaccination_wont_happen_outcome }

      it { should eq(:triage_vaccination_wont_happen) }
    end

    context "when the template indicates triage vaccination at clinic" do
      let(:template_name) { :triage_vaccination_at_clinic_outcome }

      it { should eq(:triage_vaccination_at_clinic) }
    end

    context "when the template indicates a triage delay vaccination update" do
      let(:template_name) { :triage_delay_vaccination_outcome }

      it { should eq(:triage_delay_vaccination) }
    end

    context "when the template indicates vaccination administered" do
      let(:template_name) { :vaccination_administered_notification }

      it { should eq(:vaccination_administered) }
    end

    context "when the template indicates vaccination already had" do
      let(:template_name) { :vaccination_already_had_notification }

      it { should eq(:vaccination_already_had) }
    end

    context "when the template indicates vaccination not administered" do
      let(:template_name) { :vaccination_not_administered_notification }

      it { should eq(:vaccination_not_administered) }
    end

    context "when the template indicates vaccination deleted" do
      let(:template_name) { :vaccination_deleted_notification }

      it { should eq(:vaccination_deleted) }
    end

    context "when the template name does not match any known purpose" do
      let(:template_name) { :something_else_entirely }

      it { should be_nil }
    end
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
