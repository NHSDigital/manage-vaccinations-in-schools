# frozen_string_literal: true

describe GovukNotifyPersonalisation::MmrDetailsPresenter do
  subject(:mmr_details_presenter) { described_class.new(personalisation) }

  include_context "govuk notify personalisation context"

  context "when session is in the future" do
    around { |example| travel_to(Date.new(2025, 9, 1)) { example.run } }

    it do
      expect(mmr_details_presenter).to have_attributes(
        invitation_to_clinic_custom_mmr_message: "",
        invitation_to_clinic_generic_message:
          "They can have this vaccination at a community clinic. If you’d like " \
            "to book a clinic appointment, please contact us using the details " \
            "below.",
        mmr_second_dose_required?: false
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
    end

    context "when it's an MMR programme and patient is NOT eligible for MMRV" do
      let(:programmes) { [Programme.mmr] }
      let(:date_of_birth) { Programme::MIN_MMRV_ELIGIBILITY_DATE - 1.month }

      it { should have_attributes(mmr_or_mmrv_vaccine: "MMR vaccine") }
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
          expect(mmr_details_presenter).to have_attributes(
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
          expect(mmr_details_presenter).to have_attributes(
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
          expect(mmr_details_presenter).to have_attributes(
            mmr_second_dose_required?: false,
            invitation_to_clinic_custom_mmr_message: ""
          )
        end
      end

      context "Coventry & Warwickshire (RYG) message inviting patient to clinic" do
        let(:ods_code) { "RYG" }
        let(:session) { nil }

        it do
          expect(mmr_details_presenter).to have_attributes(
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
            expect(mmr_details_presenter).to have_attributes(
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
            expect(mmr_details_presenter).to have_attributes(
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
            expect(mmr_details_presenter).to have_attributes(
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
end
