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
#  other_name                   :string
#  phone                        :string
#  phone_receive_updates        :boolean          default(FALSE), not null
#  type                         :enum
#  created_at                   :datetime         not null
#  updated_at                   :datetime         not null
#  patient_id                   :bigint
#
# Indexes
#
#  index_parents_on_email       (email)
#  index_parents_on_patient_id  (patient_id)
#
# Foreign Keys
#
#  fk_rails_...  (patient_id => patients.id)
#

describe Parent do
  describe "validations" do
    it { should_not validate_presence_of(:email) }
    it { should_not validate_presence_of(:full_name) }
    it { should_not validate_presence_of(:phone) }

    context "when users wants to receive text updates" do
      subject(:parent) { build(:parent, phone_receive_updates: true) }

      it { should validate_presence_of(:phone) }
    end

    context "when type is other" do
      subject(:parent_relationship) do
        build(:parent_relationship, type: "other")
      end

      it { should validate_presence_of(:other_name) }
    end

    context "when type is not other" do
      subject(:parent_relationship) do
        build(:parent_relationship, type: "mother", other_name: "Mother")
      end

      it "sets the other name to nil" do
        expect(parent_relationship.valid?).to be true
        expect(parent_relationship.other_name).to be_nil
      end
    end
  end

  it_behaves_like "a model with a normalised email address"
  it_behaves_like "a model with a normalised phone number"

  describe "#contactable?" do
    subject(:contactable?) { parent.contactable? }

    context "without a phone number or email address" do
      let(:parent) { build(:parent, phone: nil, email: nil) }

      it { should be(false) }
    end

    context "with a phone number" do
      let(:parent) { build(:parent, email: nil) }

      it { should be(true) }
    end

    context "with an email address" do
      let(:parent) { build(:parent, phone: nil) }

      it { should be(true) }
    end

    context "with a phone number and an email address" do
      let(:parent) { build(:parent) }

      it { should be(true) }
    end
  end

  describe "#label" do
    subject(:label) { parent.label }

    context "with a full name" do
      let(:parent) { create(:parent, full_name: "John Smith") }

      it { should eq("John Smith") }
    end

    context "without a full name" do
      let(:parent) { create(:parent, full_name: nil) }

      it { should eq("Parent or guardian (name unknown)") }
    end
  end

  describe "#contact_label" do
    subject(:contact_label) { parent.contact_label }

    context "without contact details" do
      let(:parent) { create(:parent, email: nil, phone: nil) }

      it { should be_blank }
    end

    context "with an email address" do
      let(:parent) { create(:parent, email: "test@example.com", phone: nil) }

      it { should eq("test@example.com") }
    end

    context "with a phone number" do
      let(:parent) { create(:parent, email: nil, phone: "07700900123") }

      it { should eq("07700 900123") }
    end

    context "with both" do
      let(:parent) do
        create(:parent, email: "test@example.com", phone: "07700900123")
      end

      it { should eq("test@example.com / 07700 900123") }
    end
  end

  describe "#contact_method_description" do
    subject(:contact_method_description) { parent.contact_method_description }

    context "when the parent/carer can only receive texts" do
      let(:parent) { build(:parent, :contact_method_text) }

      it { should eq("Can only receive text messages") }
    end

    context "when the parent/carer can only receive calls" do
      let(:parent) { build(:parent, :contact_method_voice) }

      it { should eq("Can only receive voice calls") }
    end

    context "when the parent/carer has no preference either way" do
      let(:parent) { build(:parent, :contact_method_any) }

      it { should eq("No specific needs") }
    end

    context "when the parent/carer has other preferences" do
      let(:parent) do
        build(
          :parent,
          :contact_method_other,
          contact_method_other_details:
            "Please call 01234 567890 ext 8910 between 9am and 5pm."
        )
      end

      it do
        expect(contact_method_description).to eq(
          "Other – Please call 01234 567890 ext 8910 between 9am and 5pm."
        )
      end
    end
  end

  describe "#email_delivery_status" do
    subject(:email_delivery_status) { parent.email_delivery_status }

    let(:parent) { create(:parent) }

    it { should be_nil }

    context "with a delivered notify log entry" do
      before do
        create(
          :notify_log_entry,
          :email,
          :delivered,
          parent:,
          recipient: parent.email
        )
      end

      it { should eq("delivered") }
    end

    context "with a failed notify log entry" do
      before do
        create(
          :notify_log_entry,
          :email,
          :permanent_failure,
          parent:,
          recipient: parent.email
        )
      end

      it { should eq("permanent_failure") }
    end

    context "with an old email address" do
      before do
        create(
          :notify_log_entry,
          :email,
          :temporary_failure,
          parent:,
          recipient: "old@example.com"
        )
      end

      it { should be_nil }
    end

    context "with multiple log entries" do
      before do
        create(
          :notify_log_entry,
          :email,
          :temporary_failure,
          parent:,
          recipient: parent.email
        )
        create(
          :notify_log_entry,
          :email,
          :delivered,
          parent:,
          recipient: parent.email
        )
      end

      it { should eq("delivered") }
    end
  end

  describe "#sms_delivery_status" do
    subject(:sms_delivery_status) { parent.sms_delivery_status }

    let(:parent) { create(:parent) }

    it { should be_nil }

    context "with a delivered notify log entry" do
      before do
        create(
          :notify_log_entry,
          :sms,
          :delivered,
          parent:,
          recipient: parent.phone
        )
      end

      it { should eq("delivered") }
    end

    context "with a failed notify log entry" do
      before do
        create(
          :notify_log_entry,
          :sms,
          :permanent_failure,
          parent:,
          recipient: parent.phone
        )
      end

      it { should eq("permanent_failure") }
    end

    context "with an old email address" do
      before do
        create(
          :notify_log_entry,
          :sms,
          :temporary_failure,
          parent:,
          recipient: "03003112233"
        )
      end

      it { should be_nil }
    end

    context "with multiple log entries" do
      before do
        create(
          :notify_log_entry,
          :sms,
          :temporary_failure,
          parent:,
          recipient: parent.phone
        )
        create(
          :notify_log_entry,
          :sms,
          :delivered,
          parent:,
          recipient: parent.phone
        )
      end

      it { should eq("delivered") }
    end
  end

  describe "#reset_unused_attributes" do
    it "resets contact method fields when phone number is removed" do
      subject =
        build(:parent, :contact_method_other, phone_receive_updates: false)
      subject.update!(phone: nil)
      expect(subject.contact_method_type).to be_nil
      expect(subject.contact_method_other_details).to be_nil
    end
  end
end
