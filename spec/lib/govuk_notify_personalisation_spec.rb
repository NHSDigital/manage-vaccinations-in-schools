# frozen_string_literal: true

# To visualise how GOV.UK Notify templates look with actual data populated
# read the instructions in spec/fixtures/notify_template.txt

describe GovukNotifyPersonalisation do
  include_context "govuk notify personalisation context"

  context "when session is in the future" do
    around { |example| travel_to(Date.new(2025, 9, 1)) { example.run } }

    it do
      expect(personalisation).to have_attributes(
        full_and_preferred_patient_name: "John Smith",
        location_name: "Hogwarts",
        patient_date_of_birth: "1 February 2013",
        short_patient_name: "John",
        short_patient_name_apos: "John’s",
        subteam_email: "team@example.com",
        subteam_name: "Team",
        subteam_phone: "01234 567890 (option 1)",
        team_privacy_notice_url: "https://example.com/privacy-notice",
        team_privacy_policy_url: "https://example.com/privacy-policy"
      )
    end
  end

  context "with a patient in primary school" do
    let(:date_of_birth) { Date.new(2015, 2, 1) }
    let(:patient) { create(:patient, date_of_birth:) }

    context "when it's an MMR programme and patient is eligible for MMRV" do
      let(:programmes) { [Programme.mmr] }
      let(:date_of_birth) { Programme::MIN_MMRV_ELIGIBILITY_DATE + 1.month }

      it { expect(personalisation.outbreak?).to be false }

      context "when session is setup for outbreak communications" do
        before { allow(session).to receive(:outbreak).and_return(true) }

        it { expect(personalisation.outbreak?).to be true }
      end
    end

    context "when it's an MMR programme and patient is NOT eligible for MMRV" do
      let(:programmes) { [Programme.mmr] }
      let(:date_of_birth) { Programme::MIN_MMRV_ELIGIBILITY_DATE - 1.month }

      context "when session is setup for outbreak communications" do
        before { allow(session).to receive(:outbreak).and_return(true) }

        it { expect(personalisation.outbreak?).to be true }
      end
    end
  end

  context "with a consent form" do
    let(:consent_form) do
      create(
        :consent_form,
        :refused,
        session:,
        recorded_at: Date.new(2024, 1, 1),
        given_name: "Tom"
      )
    end

    it { should have_attributes(location_name: "Hogwarts") }

    context "where the school is different" do
      let(:session) { nil }
      let(:school) { create(:gias_school, name: "Waterloo Road", team:) }

      let(:consent_form) do
        create(
          :consent_form,
          :given,
          :recorded,
          session: create(:session, location:, programmes:, team:),
          school_confirmed: false,
          school:
        )
      end

      before { create(:session, location: school, programmes:, team:) }

      it do
        expect(personalisation).to have_attributes(
          location_name: "Waterloo Road"
        )
      end
    end
  end

  context "with the session is nil" do
    let(:session) { nil }
    let(:consent) { create(:consent, patient:, programme: programmes.first) }

    it "doesn't throw an error" do
      expect { personalisation }.not_to raise_error
    end
  end
end
