# frozen_string_literal: true

describe NotifyTemplate do
  describe ".find" do
    context "with a locally-migrated email template" do
      subject(:template) do
        described_class.find(:consent_confirmation_given, channel: :email)
      end

      it { should_not be_nil }
      it { should be_local }

      it "has a UUID as the template ID" do
        expect(template.id).to match(/\A[0-9a-f-]{36}\z/)
      end
    end

    context "with a locally-migrated SMS template" do
      subject(:template) do
        described_class.find(:consent_confirmation_given, channel: :sms)
      end

      it { should_not be_nil }
      it { should be_local }
    end

    context "with an unknown template name" do
      subject(:template) do
        described_class.find(:nonexistent_template, channel: :email)
      end

      it { should be_nil }
    end
  end

  describe ".find_by_id" do
    context "with a locally-migrated template's ID" do
      subject(:template) do
        described_class.find_by_id(template_id, channel: :email)
      end

      let(:template_id) do
        described_class.find(:consent_confirmation_given, channel: :email).id
      end

      it { should_not be_nil }
      it { should be_local }

      it "resolves the template name" do
        expect(template.name).to eq(:consent_confirmation_given)
      end
    end

    context "with a retired template's ID" do
      subject(:template) do
        described_class.find_by_id(template_id, channel: :email)
      end

      let(:template_id) { NotifyTemplate::RETIRED_TEMPLATE_IDS.keys.first }

      it { should_not be_nil }

      it "resolves the template name" do
        expect(template.name).to eq(
          NotifyTemplate::RETIRED_TEMPLATE_IDS[template_id]
        )
      end
    end

    context "with an unknown ID" do
      subject(:template) do
        described_class.find_by_id(
          "00000000-0000-0000-0000-000000000000",
          channel: :email
        )
      end

      it { should be_nil }
    end

    context "with a blank ID" do
      subject(:template) { described_class.find_by_id(nil, channel: :email) }

      it { should be_nil }
    end
  end

  describe ".exists?" do
    context "with a locally-migrated template" do
      it "returns true for source: :local" do
        expect(
          described_class.exists?(
            :consent_confirmation_given,
            channel: :email,
            source: :local
          )
        ).to be true
      end

      it "returns true for source: :any (default)" do
        expect(
          described_class.exists?(:consent_confirmation_given, channel: :email)
        ).to be true
      end
    end

    context "with an unknown template" do
      it "returns false" do
        expect(
          described_class.exists?(:nonexistent, channel: :email)
        ).to be false
      end
    end

    context "with an unknown source" do
      it "raises ArgumentError" do
        expect {
          described_class.exists?(
            :consent_school_request_hpv,
            channel: :email,
            source: :unknown
          )
        }.to raise_error(ArgumentError, /Unknown source/)
      end
    end
  end
end
