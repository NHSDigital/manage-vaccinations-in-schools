# frozen_string_literal: true

describe SessionSearchForm do
  subject(:form) do
    described_class.new(request_session:, request_path:, **params)
  end

  around { |example| travel_to(Date.new(2025, 7, 1)) { example.run } }

  let(:request_session) { {} }
  let(:request_path) { "/sessions" }
  let(:params) { {} }

  let(:scope) { Session.all }

  it "doesn't raise an error" do
    expect { form.apply(scope) }.not_to raise_error
  end

  context "when filtering by academic year" do
    let(:params) { { "academic_year" => "2025" } }

    let(:programmes) { [Programme.sample] }

    let!(:session_to_include) do
      create(
        :session,
        academic_year: 2025,
        date: Date.new(2025, 9, 1),
        programmes:
      )
    end

    before do
      create(
        :session,
        academic_year: 2024,
        date: Date.new(2024, 9, 1),
        programmes:
      )
    end

    it "filters on the sessions" do
      expect(form.apply(scope)).to contain_exactly(session_to_include)
    end
  end

  context "when filtering by programmes" do
    let(:params) { { "programmes" => %w[flu] } }

    let(:flu_programmes) { Programme.flu }
    let(:hpv_programmes) { Programme.hpv }

    let!(:session_to_include) { create(:session, programmes: [flu_programmes]) }

    before { create(:session, programmes: [hpv_programmes]) }

    it "filters on the sessions" do
      expect(form.apply(scope)).to contain_exactly(session_to_include)
    end
  end

  context "when filtering by name" do
    let(:params) { { "q" => "School" } }

    let(:programmes) { [Programme.sample] }

    let!(:session_to_include) do
      create(
        :session,
        location: create(:gias_school, name: "School"),
        programmes:
      )
    end

    before do
      create(
        :session,
        location: create(:gp_practice, name: "GP Practice"),
        programmes:
      )
    end

    it "filters on the sessions" do
      expect(form.apply(scope)).to contain_exactly(session_to_include)
    end
  end

  context "when filtering on the type" do
    let(:params) { { "type" => "gias_school" } }

    let(:programmes) { [Programme.sample] }

    let!(:session_to_include) do
      create(
        :session,
        location: create(:gias_school, name: "School"),
        programmes:
      )
    end

    before do
      create(
        :session,
        location: create(:gp_practice, name: "GP Practice"),
        programmes:
      )
    end

    it "filters on the sessions" do
      expect(form.apply(scope)).to contain_exactly(session_to_include)
    end
  end

  context "when filtering on the status" do
    let(:programmes) { [Programme.sample] }

    let!(:today_session) { create(:session, :today, programmes:) }
    let!(:unscheduled_session) { create(:session, :unscheduled, programmes:) }
    let!(:scheduled_session) { create(:session, :scheduled, programmes:) }
    let!(:completed_session) { create(:session, :completed, programmes:) }
    let!(:cancelled_session) do
      create(:session, :scheduled, :cancelled, programmes:)
    end

    context "when status is blank" do
      let(:params) { { "status" => "" } }

      it "excludes cancelled sessions" do
        expect(form.apply(scope)).to contain_exactly(
          completed_session,
          scheduled_session,
          today_session,
          unscheduled_session
        )
      end
    end

    context "when status is in progress" do
      let(:params) { { "status" => "in_progress" } }

      it "filters on the sessions" do
        expect(form.apply(scope)).to contain_exactly(today_session)
      end
    end

    context "when status is unscheduled" do
      let(:params) { { "status" => "unscheduled" } }

      it "filters on the sessions" do
        expect(form.apply(scope)).to contain_exactly(unscheduled_session)
      end
    end

    context "when status is scheduled" do
      let(:params) { { "status" => "scheduled" } }

      it "filters on the sessions" do
        expect(form.apply(scope)).to contain_exactly(
          scheduled_session,
          today_session
        )
      end
    end

    context "when status is completed" do
      let(:params) { { "status" => "completed" } }

      it "filters on the sessions" do
        expect(form.apply(scope)).to contain_exactly(completed_session)
      end
    end

    context "when status is cancelled" do
      let(:params) { { "status" => "cancelled" } }

      it "filters on the sessions" do
        expect(form.apply(scope)).to contain_exactly(cancelled_session)
      end
    end
  end
end
