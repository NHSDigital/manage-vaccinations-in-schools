# frozen_string_literal: true

describe AppSessionSearchFormComponent do
  subject(:rendered) { travel_to(today) { render_inline(component) } }

  let(:component) do
    described_class.new(form, url:, academic_years:, programmes:)
  end

  let(:form) { SessionSearchForm.new(request_session: {}, request_path: "/") }
  let(:url) { "/form" }
  let(:programmes) { Programme.all }
  let(:academic_years) { true }

  let(:today) { Date.current }

  it { should have_content("Find session") }
  it { should have_button("Update results") }
  it { should_not have_content("Cancelled") }

  it do
    expect(rendered).to have_link("Clear filters", href: "/form?_clear=true")
  end

  context "when the cancellation feature is enabled" do
    before { Flipper.enable(:clinic_sessions) }
    after { Flipper.disable(:clinic_sessions) }

    it { should have_content("Cancelled") }
  end

  context "during preparation for next year" do
    let(:today) { Date.new(2025, 8, 1) }

    it { should have_content("Academic year") }
    it { should have_content("2024 to 2025") }
    it { should have_content("2025 to 2026") }

    context "when not showing academic years" do
      let(:academic_years) { false }

      it { should_not have_content("Academic year") }
      it { should_not have_content("2024 to 2025") }
      it { should_not have_content("2025 to 2026") }
    end
  end

  context "after preparation for next year" do
    let(:today) { Date.new(2025, 9, 1) }

    it { should_not have_content("Academic year") }
    it { should_not have_content("2024 to 2025") }
    it { should_not have_content("2025 to 2026") }
  end
end
