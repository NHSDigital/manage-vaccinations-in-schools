# frozen_string_literal: true

describe GovukNotifyPersonalisation::ConsentDetailsPresenter do
  subject(:consent_details_presenter) { described_class.new(personalisation) }

  include_context "govuk notify personalisation context"

  context "when session is in the future" do
    around { |example| travel_to(Date.new(2025, 9, 1)) { example.run } }

    it do
      expect(consent_details_presenter).to have_attributes(
        talk_to_your_child_message:
          "## Talk to your child about what they want\n\nWe suggest you talk to " \
            "your child about the vaccination before you respond to us. Young " \
            "people have the right to refuse vaccinations.\n\nThey also have " \
            "[the right to consent to their own vaccinations]" \
            "(https://www.nhs.uk/conditions/consent-to-treatment/children/) " \
            "if they show they fully understand what’s involved. Our team might " \
            "give young people this opportunity if they assess them as suitably " \
            "competent.",
        consent_deadline: "Wednesday 31 December",
        consent_link: "http://localhost:4000/consents/#{session.slug}/hpv/start"
      )
    end
  end

  context "with a team location and no session" do
    let(:location) { create(:gias_school) }
    let(:team_location) { create(:team_location, team:, location:) }
    let(:session) { nil }

    it do
      expect(consent_details_presenter).to have_attributes(
        consent_link:
          "http://localhost:4000/consents/#{team_location.id}/hpv/start"
      )
    end
  end

  context "with a patient in primary school" do
    let(:date_of_birth) { Date.new(2015, 2, 1) }
    let(:patient) { create(:patient, date_of_birth:) }

    it { should have_attributes(talk_to_your_child_message: "") }

    context "when it's an MMR programme and patient is eligible for MMRV" do
      let(:programmes) { [Programme.mmr] }
      let(:date_of_birth) { Programme::MIN_MMRV_ELIGIBILITY_DATE + 1.month }

      it "generates consent link with mmrv variant" do
        expect(consent_details_presenter.consent_link).to end_with(
          "/mmrv/start"
        )
      end
    end

    context "when it's an MMR programme and patient is NOT eligible for MMRV" do
      let(:programmes) { [Programme.mmr] }
      let(:date_of_birth) { Programme::MIN_MMRV_ELIGIBILITY_DATE - 1.month }

      it "generates consent link with mmr variant" do
        expect(consent_details_presenter.consent_link).to end_with("/mmr/start")
      end
    end
  end

  context "with a consent" do
    let(:consent) do
      create(
        :consent,
        :refused,
        programme: programmes.first,
        created_at: Date.new(2024, 1, 1)
      )
    end

    it do
      expect(consent_details_presenter).to have_attributes(
        consented_vaccine_methods_message: "",
        reason_for_refusal: "of personal choice",
        survey_deadline_date: "8 January 2024"
      )
    end

    context "for the flu programme" do
      let(:programmes) { [Programme.flu] }

      it do
        expect(consent_details_presenter).to have_attributes(
          consented_vaccine_methods_message:
            "You’ve agreed for John to have the injected flu vaccine."
        )
      end

      context "when consented to both nasal and injection" do
        before { consent.update!(vaccine_methods: %w[nasal injection]) }

        it do
          expect(consent_details_presenter).to have_attributes(
            consented_vaccine_methods_message:
              "You’ve agreed for John to have the nasal spray flu vaccine, " \
                "or the injected flu vaccine if the nasal spray is not suitable."
          )
        end
      end

      context "when consented only to nasal" do
        before { consent.update!(vaccine_methods: %w[nasal]) }

        it do
          expect(consent_details_presenter).to have_attributes(
            consented_vaccine_methods_message:
              "You’ve agreed for John to have the nasal spray flu vaccine."
          )
        end
      end
    end

    context "for the MMR programme" do
      let(:programmes) { [Programme.mmr] }
      let(:patient) do
        create(
          :patient,
          session:,
          given_name: "John",
          family_name: "Smith",
          year_group: 9
        )
      end

      it { should have_attributes(consented_vaccine_methods_message: "") }

      context "when consented to vaccine without gelatine" do
        before { consent.update!(without_gelatine: true) }

        it do
          expect(consent_details_presenter).to have_attributes(
            consented_vaccine_methods_message:
              "You’ve agreed for John to have the vaccine without gelatine."
          )
        end
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

    it do
      expect(consent_details_presenter).to have_attributes(
        consented_vaccine_methods_message: "",
        reason_for_refusal: "of personal choice",
        survey_deadline_date: "8 January 2024"
      )
    end

    describe "#follow_up_discussion" do
      subject(:follow_up_discussion) do
        described_class.new(personalisation).follow_up_discussion
      end

      it "is nil when follow_up_requested is not set" do
        expect(follow_up_discussion).to be_nil
      end

      context "when follow_up_requested is true" do
        before do
          consent_form.consent_form_programmes.update!(
            follow_up_requested: true
          )
        end

        it { should be(true) }
      end

      context "when follow_up_requested is false" do
        before do
          consent_form.consent_form_programmes.update!(
            follow_up_requested: false
          )
        end

        it { should be(false) }
      end
    end

    context "for the flu programme" do
      let(:programmes) { [Programme.flu] }

      it do
        expect(consent_details_presenter).to have_attributes(
          consented_vaccine_methods_message:
            "You’ve agreed for Tom to have the injected flu vaccine."
        )
      end

      context "when consented to both nasal and injection" do
        before do
          consent_form.consent_form_programmes.update!(
            vaccine_methods: %w[nasal injection]
          )
        end

        it do
          expect(consent_details_presenter).to have_attributes(
            consented_vaccine_methods_message:
              "You’ve agreed for Tom to have the nasal spray flu vaccine, " \
                "or the injected flu vaccine if the nasal spray is not suitable."
          )
        end
      end

      context "when consented only to nasal" do
        before do
          consent_form.consent_form_programmes.update!(
            vaccine_methods: %w[nasal]
          )
        end

        it do
          expect(consent_details_presenter).to have_attributes(
            consented_vaccine_methods_message:
              "You’ve agreed for Tom to have the nasal spray flu vaccine."
          )
        end
      end
    end

    context "for the MMR programme" do
      let(:programmes) { [Programme.mmr] }

      it { should have_attributes(consented_vaccine_methods_message: "") }

      context "when consented to vaccine without gelatine" do
        before do
          consent_form.consent_form_programmes.update!(without_gelatine: true)
        end

        it do
          expect(consent_details_presenter).to have_attributes(
            consented_vaccine_methods_message:
              "You’ve agreed for Tom to have the vaccine without gelatine."
          )
        end
      end
    end
  end
end
