# frozen_string_literal: true

describe AppFlashMessageComponent do
  subject(:rendered) { render_inline(component) }

  let(:component) { described_class.new(flash:) }

  context "when no flash message is provided" do
    let(:flash) { {} }

    it { should have_text("", exact: true) }
  end

  describe "the render? method" do
    subject { component.render? }

    context "when a message is provided" do
      let(:flash) { { success: "Success message" } }

      it { should be true }
    end

    context "when a message is not provided" do
      let(:flash) { {} }

      it { should be false }
    end
  end

  context "when an unknown flash key is provided" do
    let(:flash) { { unknown: "Message" } }

    it { should have_text("", exact: true) }
  end

  context "when a simple string is provided" do
    let(:flash) { { success: "Success message" } }

    it "puts the text in the banner heading" do
      expect(rendered.css(".nhsuk-notification-banner__heading").text).to(
        include("Success message")
      )
    end
  end

  context "when an array is provided" do
    let(:flash) { { success: ["Success message", "You win!"] } }

    it "puts the first line into the banner heading" do
      expect(rendered.css(".nhsuk-notification-banner__heading").text).to(
        include("Success message")
      )
    end

    it "puts the rest of the lines into the banner body" do
      expect(rendered.css(".nhsuk-notification-banner__content").text).to(
        include("You win!")
      )
    end

    it { should have_css("p", text: "You win!") }
  end

  context "when a hash is provided" do
    let(:flash) do
      {
        success: {
          title: "Success title",
          heading: "Success heading",
          body: "Success body"
        }
      }.with_indifferent_access
    end

    it "puts the title into the banner title" do
      expect(rendered.css(".nhsuk-notification-banner__title").text).to(
        include("Success title")
      )
    end

    it "puts the heading into the banner heading" do
      expect(rendered.css(".nhsuk-notification-banner__heading").text).to(
        include("Success heading")
      )
    end

    it "puts the body into the main content" do
      expect(rendered.css(".nhsuk-notification-banner__content").text).to(
        include("Success body")
      )
    end

    context "when heading contains HTML but is not marked as safe" do
      before { flash[:success][:heading] = "<p>HTML</p>" }

      it "doesn't render the heading as HTML" do
        expect(
          rendered.css(".nhsuk-notification-banner__content").inner_html
        ).to(include("&lt;p&gt;HTML&lt;/p&gt;"))
      end
    end

    context "when body contains HTML that is marked as safe" do
      before { flash[:success][:body] = "<p>HTML</p>".html_safe }

      it "doesn't render the body as HTML" do
        expect(
          rendered.css(".nhsuk-notification-banner__content").inner_html
        ).to(include("<p>HTML</p>"))
      end
    end

    context "when body contains HTML but is not marked as safe" do
      before { flash[:success][:body] = "<p>HTML</p>" }

      it "doesn't render the body as HTML" do
        expect(
          rendered.css(".nhsuk-notification-banner__content").inner_html
        ).to(include("&lt;p&gt;HTML&lt;/p&gt;"))
      end
    end
  end

  describe "the role attribute" do
    subject do
      rendered.css(".nhsuk-notification-banner").attribute("role").value
    end

    context "when a success flash key is provided" do
      let(:flash) { { success: "Success message" } }

      it { should eq "alert" }
    end

    context "when a warning flash key is provided" do
      let(:flash) { { warning: "Warning message" } }

      it { should eq "alert" }
    end

    context "when an info flash key is provided" do
      let(:flash) { { info: "Info message" } }

      it { should eq "region" }
    end

    context "when an alert flash key is provided" do
      let(:flash) { { info: "Alert message" } }

      it { should eq "region" }
    end

    context "when a notice flash key is provided" do
      let(:flash) { { info: "Notice message" } }

      it { should eq "region" }
    end
  end

  context "when a secondary message is provided" do
    let(:flash) { { info: ["Message", "Some more details..."] } }

    it "renders the correct content" do
      expect(rendered.text).to include("Message")
      expect(rendered.text).to include("Some more details...")
    end
  end

  describe "the title" do
    subject { rendered.css(".nhsuk-notification-banner__title").text.strip }

    context "when a title is provided" do
      let(:flash) { { info: { title: "Title text", body: "Message" } } }

      it { should eq "Title text" }
    end

    context "when a title is not provided" do
      let(:flash) { { info: "Message" } }

      it { should eq "Information" }
    end
  end

  describe "the banner class" do
    subject do
      rendered.css(".nhsuk-notification-banner").attribute("class").value
    end

    context "when a info flash key is provided" do
      let(:flash) { { info: "Info message" } }

      it { should include "nhsuk-notification-banner--info" }
    end

    context "when a success flash key is provided" do
      let(:flash) { { success: "Success message" } }

      it { should include "nhsuk-notification-banner--success" }
    end
  end
end
