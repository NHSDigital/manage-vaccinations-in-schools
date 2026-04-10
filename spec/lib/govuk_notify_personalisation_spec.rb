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
        invitation_to_clinic_custom_mmr_message: "",
        mmr_second_dose_required?: false,
        invitation_to_clinic_generic_message:
          "They can have this vaccination at a community clinic. If you’d like " \
            "to book a clinic appointment, please contact us using the details " \
            "below.",
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

      it { should have_attributes(mmr_or_mmrv_vaccine: "MMR or MMRV vaccine") }
      it { expect(personalisation.outbreak?).to be false }

      context "when session is setup for outbreak communications" do
        before { allow(session).to receive(:outbreak).and_return(true) }

        it { expect(personalisation.outbreak?).to be true }
      end
    end

    context "when it's an MMR programme and patient is NOT eligible for MMRV" do
      let(:programmes) { [Programme.mmr] }
      let(:date_of_birth) { Programme::MIN_MMRV_ELIGIBILITY_DATE - 1.month }

      it { should have_attributes(mmr_or_mmrv_vaccine: "MMR vaccine") }

      context "when session is setup for outbreak communications" do
        before { allow(session).to receive(:outbreak).and_return(true) }

        it { expect(personalisation.outbreak?).to be true }
      end
    end
  end

  context "delayed triage" do
    context "created on day of session" do
      let(:session) { create(:session, :today, location:, team:, programmes:) }

      before do
        create(
          :triage,
          :delay_vaccination,
          patient:,
          programme: programmes.first
        )
      end

      it do
        expect(personalisation).to have_attributes(
          delay_vaccination_review_context:
            "assessed John in the vaccination session"
        )
      end
    end

    context "created before session starts" do
      let(:session) { create(:session, :today, location:, team:, programmes:) }

      before do
        create(
          :triage,
          :delay_vaccination,
          patient:,
          created_at: Date.yesterday,
          programme: programmes.first
        )
      end

      it do
        expect(personalisation).to have_attributes(
          delay_vaccination_review_context:
            "reviewed the answers you gave to the health questions about John"
        )
      end
    end

    context "created after session starts" do
      let(:session) do
        create(:session, :yesterday, location:, team:, programmes:)
      end

      before do
        create(
          :triage,
          :delay_vaccination,
          patient:,
          programme: programmes.first
        )
      end

      it do
        expect(personalisation).to have_attributes(
          delay_vaccination_review_context:
            "reviewed the answers you gave to the health questions about John"
        )
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

    context "for the flu programme" do
      let(:programmes) { [Programme.flu] }

      context "generic message inviting patient to clinic generic" do
        it do
          expect(personalisation).to have_attributes(
            invitation_to_clinic_generic_message:
              "They can have this vaccination at a community clinic. " \
                "If you’d like to book a clinic appointment, please contact us using " \
                "the details below."
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

      context "generic message inviting patient to generic clinic" do
        it do
          expect(personalisation).to have_attributes(
            mmr_second_dose_required?: false,
            invitation_to_clinic_generic_message:
              "They can have this vaccination at a community clinic. " \
                "If you’d like to book a clinic appointment, please contact us using " \
                "the details below."
          )
        end
      end

      context "Leicestershire (RT5) message inviting patient to clinic" do
        let(:ods_code) { "RT5" }
        let(:session) { nil }

        it do
          expect(personalisation).to have_attributes(
            mmr_second_dose_required?: false,
            invitation_to_clinic_custom_mmr_message: ""
          )
        end
      end

      context "Coventry & Warwickshire (RYG) message inviting patient to clinic" do
        let(:ods_code) { "RYG" }
        let(:session) { nil }

        it do
          expect(personalisation).to have_attributes(
            mmr_second_dose_required?: false,
            invitation_to_clinic_custom_mmr_message: ""
          )
        end
      end

      context "patient has had their 1st dose" do
        before do
          create(
            :vaccination_record,
            :administered,
            programme: programmes.first,
            patient:,
            session:,
            performed_at: Date.new(2020, 1, 1)
          )

          PatientStatusUpdater.call(patient:)
        end

        context "generic message inviting patient to generic clinic for their 2nd dose" do
          it do
            expect(personalisation).to have_attributes(
              mmr_second_dose_required?: true,
              invitation_to_clinic_generic_message:
                "If you would like your local GP surgery to give John their 2nd dose, " \
                  "contact the surgery in the usual way.\n\n" \
                  "Alternatively, they can have this vaccination at a community clinic. " \
                  "If you’d like to book a clinic appointment, please contact us using " \
                  "the details below.\n\n" \
                  "It’s important to wait at least 28 days after the 1st dose of an MMR " \
                  "or MMRV vaccination before getting the 2nd dose. John should not get " \
                  "the 2nd dose until 29 January 2020. Please keep this in mind when " \
                  "booking the appointment."
            )
          end
        end

        context "Leicestershire (RT5) message inviting patient to clinic" do
          let(:ods_code) { "RT5" }

          it do
            expect(personalisation).to have_attributes(
              mmr_second_dose_required?: true,
              invitation_to_clinic_custom_mmr_message:
                "It’s important to wait at least 28 days after the 1st dose of an MMR or " \
                  "MMRV vaccination before getting the 2nd dose. John should not get the 2nd " \
                  "dose until 29 January 2020. Please keep this in mind when booking " \
                  "the appointment.\n\n" \
                  "It’s also possible for John to be vaccinated at your local GP surgery. " \
                  "To book an appointment, contact the surgery in the usual way."
            )
          end
        end

        context "Coventry & Warwickshire (RYG) message inviting patient to clinic" do
          let(:ods_code) { "RYG" }

          it do
            expect(personalisation).to have_attributes(
              mmr_second_dose_required?: true,
              invitation_to_clinic_custom_mmr_message:
                "It’s important to wait at least 28 days after the 1st dose of an MMR " \
                  "or MMRV vaccination before getting the 2nd dose. John should not get the 2nd " \
                  "dose until 29 January 2020. Please keep this in mind when booking " \
                  "the appointment.\n\n" \
                  "## You have 2 options for booking the vaccination\n\n" \
                  "You can ask your local GP surgery to give John their 2nd dose. To " \
                  "book an appointment, contact the surgery in the usual way."
            )
          end
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
