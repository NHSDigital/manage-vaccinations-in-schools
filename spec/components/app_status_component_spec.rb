# frozen_string_literal: true

describe AppStatusComponent do
  subject(:rendered) { render_inline(component) }

  let(:component) { described_class.new(text: "Some status", colour:, icon:) }
  let(:colour) { "blue" }
  let(:icon) { :warning }

  it { should have_css("p.app-status.app-status--blue", text: "Some status") }
  it { should have_css("svg.nhsuk-icon--warning") }

  context "with colour: 'green'" do
    let(:colour) { "green" }

    it { should have_css("p.app-status.app-status--green") }
  end

  context "with icon: :tick" do
    let(:icon) { :tick }

    it { should have_css("svg.nhsuk-icon--tick") }
    it { should_not have_css("svg.nhsuk-icon--warning") }
  end

  context "with icon: :cross" do
    let(:icon) { :cross }

    it { should have_css("svg.nhsuk-icon--cross") }
    it { should_not have_css("svg.nhsuk-icon--warning") }
  end

  context "with an unknown icon" do
    let(:icon) { :unknown }

    it { expect { rendered }.to raise_error(ArgumentError) }
  end

  context "with small: true" do
    let(:component) { described_class.new(text: "Some status", small: true) }

    it { should have_css("p.app-status.app-status--small") }
  end

  context "with extra classes" do
    let(:component) do
      described_class.new(
        text: "Some status",
        classes: "nhsuk-u-margin-bottom-0"
      )
    end

    it { should have_css("p.app-status.nhsuk-u-margin-bottom-0") }
  end
end
