# frozen_string_literal: true

describe LocationSearchForm do
  subject(:form) do
    described_class.new(request_session:, request_path:, **params)
  end

  let(:request_session) { {} }
  let(:request_path) { "/schools" }
  let(:params) { {} }

  let(:scope) { Location.gias_school.all }

  it "doesn't raise an error" do
    expect { form.apply(scope) }.not_to raise_error
  end

  context "when filtering by name" do
    let(:params) { { "q" => "Primary" } }

    let!(:school_to_include) { create(:gias_school, :primary, name: "Primary") }

    before { create(:gias_school, :secondary, name: "Secondary") }

    it "filters on the schools" do
      expect(form.apply(scope)).to contain_exactly(school_to_include)
    end
  end

  context "when filtering on the phase" do
    let(:params) { { "phase" => "primary" } }

    let!(:school_to_include) { create(:gias_school, :primary, name: "Primary") }

    before { create(:gias_school, :secondary, name: "Secondary") }

    it "filters on the schools" do
      expect(form.apply(scope)).to contain_exactly(school_to_include)
    end
  end
end
