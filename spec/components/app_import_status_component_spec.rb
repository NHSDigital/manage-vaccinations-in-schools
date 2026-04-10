# frozen_string_literal: true

describe AppImportStatusComponent do
  subject(:rendered) { render_inline(component) }

  let(:component) { described_class.new(import:, break_tag:) }
  let(:import) do
    instance_double(ClassImport, status:, pending_import?: pending_import)
  end
  let(:break_tag) { false }
  let(:pending_import) { false }

  context "when status is pending_import" do
    let(:status) { "pending_import" }
    let(:pending_import) { true }

    it { should have_css(".nhsuk-tag--blue", text: "Processing") }
  end

  context "when status is rows_are_invalid" do
    let(:status) { "rows_are_invalid" }

    it { should have_css(".nhsuk-tag--red", text: "Invalid") }
  end

  context "when status is changesets_are_invalid" do
    let(:status) { "changesets_are_invalid" }

    it { should have_css(".nhsuk-tag--red", text: "Failed") }
  end

  context "when status is processed" do
    let(:status) { "processed" }

    it { should have_css(".nhsuk-tag--green", text: "Completed") }
  end

  context "when status is removing_parent_relationships" do
    let(:status) { "removing_parent_relationships" }

    it { should have_css(".nhsuk-tag--green", text: "Completed") }
  end
end
