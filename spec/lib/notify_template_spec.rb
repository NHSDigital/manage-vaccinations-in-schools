# frozen_string_literal: true

describe NotifyTemplate do
  describe ".find" do
    context "with a local email template" do
      subject(:template) do
        described_class.find(:consent_confirmation_given, channel: :email)
      end

      it { should_not be_nil }

      it "has a UUID as the template ID" do
        expect(template.id).to eq("c6c8dbfc-b429-4468-bd0b-176e771b5a8e")
      end
    end

    context "with a local SMS template" do
      subject(:template) do
        described_class.find(:consent_confirmation_given, channel: :sms)
      end

      it { should_not be_nil }

      it "has a UUID as the template ID" do
        expect(template.id).to eq("8eb8d05e-b8d8-4bf9-8a38-c009ae989a4e")
      end
    end

    context "with an unknown template name" do
      subject(:template) do
        described_class.find(:nonexistent_template, channel: :email)
      end

      it { should be_nil }
    end
  end

  describe ".find_by_id" do
    context "with a local template's ID" do
      subject(:template) do
        described_class.find_by_id(template_id, channel: :email)
      end

      let(:template_id) do
        described_class.find(:consent_confirmation_given, channel: :email).id
      end

      it { should_not be_nil }

      it "resolves the template name" do
        expect(template.name).to eq(:consent_confirmation_given)
      end
    end

    context "with a retired template's ID" do
      subject(:template) do
        described_class.find_by_id(template_id, channel: :email)
      end

      let(:template_id) { NotifyLogEntry::RETIRED_TEMPLATE_IDS.keys.first }

      it { should be_nil }
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
    it "returns true for a local template" do
      expect(
        described_class.exists?(:consent_confirmation_given, channel: :email)
      ).to be true
    end

    it "returns false for an unknown template" do
      expect(described_class.exists?(:nonexistent, channel: :email)).to be false
    end
  end

  describe ".all_ids" do
    it "includes the ID of a known local template" do
      id = described_class.find(:consent_confirmation_given, channel: :email).id
      expect(described_class.all_ids(channel: :email)).to include(id)
    end
  end

  describe "frontmatter parsing" do
    it "parses frontmatter and body from ERB content" do
      content = "---\ntemplate_id: \"abc\"\n---\nHello world\n"
      template = described_class.new(name: :test, channel: :email, content:)
      expect(template.id).to eq("abc")
      expect(template.render(Object.new)).to eq(
        { subject: "", body: "Hello world\n" }
      )
    end

    it "returns empty frontmatter when no delimiter present" do
      content = "Hello world\n"
      template = described_class.new(name: :test, channel: :email, content:)
      expect(template.id).to be_nil
      expect(template.render(Object.new)).to eq(
        { subject: "", body: "Hello world\n" }
      )
    end
  end

  describe "#render" do
    context "when the template references an undefined variable" do
      subject(:template) do
        described_class.find(:consent_confirmation_given, channel: :email)
      end

      it "raises NameError mentioning the channel and template name" do
        expect { template.render(Object.new) }.to raise_error(
          NameError,
          /in email template 'consent_confirmation_given'/
        )
      end
    end
  end

  context "local SMS templates" do
    # smart quotes should not be used in SMS template bodies and subject lines
    # to avoid Notify switching to UCS-2 encoding and
    # dropping the character limit per SMS to 70 characters
    # https://www.notifications.service.gov.uk/pricing/text-messages

    it "does not contain any smart quotes of any kind" do
      described_class
        .all_ids(channel: :sms)
        .each do |id|
          template = described_class.find_by_id(id, channel: :sms)
          %w[“ ’ ’ ”].each do |quote|
            expect(template.body).not_to include(quote),
            "template #{template.id} (#{template.name}) body should not include #{quote.inspect}"
            expect(template.subject).not_to include(quote),
            "template #{template.id} (#{template.name}) subject should not include #{quote.inspect}"
          end
        end
    end
  end

  context "local email templates" do
    it "uses smart apostrophes instead of straight apostrophe" do
      straight_apostrophe = "'"
      described_class
        .all_ids(channel: :email)
        .each do |id|
          template = described_class.find_by_id(id, channel: :email)
          expect(template.body).not_to include(straight_apostrophe),
          "template #{template.id} (#{template.name}) body should not include #{straight_apostrophe.inspect}"
          expect(template.subject).not_to include(straight_apostrophe),
          "template #{template.id} (#{template.name}) subject should not include #{straight_apostrophe.inspect}"
        end
    end
  end
end
