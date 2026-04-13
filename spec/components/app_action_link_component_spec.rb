# frozen_string_literal: true

describe AppActionLinkComponent do
  subject(:rendered) { render_inline(component) }

  let(:component) { described_class.new(text:, href:) }
  let(:text) { "Get started" }
  let(:href) { "/get-started" }

  it { should have_css(".nhsuk-action-link") }
  it { should have_css(".nhsuk-action-link__text", text: "Get started") }

  it "links to the correct href" do
    expect(rendered).to have_css("a.nhsuk-action-link[href='/get-started']")
  end

  it "renders the arrow icon" do
    expect(rendered).to have_css(
      "svg.nhsuk-icon.nhsuk-icon--arrow-right-circle"
    )
  end

  it "marks the icon as decorative" do
    expect(rendered).to have_css("svg[aria-hidden='true'][focusable='false']")
  end

  context "when passing extra link options" do
    let(:component) do
      described_class.new(
        text:,
        href:,
        target: "_blank",
        rel: "noopener noreferrer"
      )
    end

    it "passes target through to the link" do
      expect(rendered).to have_css("a[target='_blank']")
    end

    it "passes rel through to the link" do
      expect(rendered).to have_css("a[rel='noopener noreferrer']")
    end
  end

  context "when passing an extra class" do
    let(:component) do
      described_class.new(text:, href:, class: "my-extra-class")
    end

    it "includes both the default and extra classes" do
      expect(rendered).to have_css("a.nhsuk-action-link.my-extra-class")
    end
  end

  context "when passing data attributes" do
    let(:component) do
      described_class.new(text:, href:, data: { turbo_method: :delete })
    end

    it "passes data attributes through to the link" do
      expect(rendered).to have_css("a[data-turbo-method='delete']")
    end
  end
end
