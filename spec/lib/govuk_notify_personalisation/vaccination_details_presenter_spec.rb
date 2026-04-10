# frozen_string_literal: true

describe GovukNotifyPersonalisation::VaccinationDetailsPresenter do
  subject(:vaccination_details_presenter) do
    described_class.new(personalisation)
  end

  include_context "govuk notify personalisation context"

  context "when session is in the future" do
    around { |example| travel_to(Date.new(2025, 9, 1)) { example.run } }

    it do
      expect(vaccination_details_presenter).to have_attributes(
        vaccination: "HPV vaccination",
        vaccination_and_dates: "HPV vaccination on Thursday 1 January",
        vaccination_and_dates_sms: "HPV vaccination on Thursday 1 January",
        vaccination_and_method: "HPV vaccination",
        vaccine: "HPV vaccine",
        vaccine_and_dose: "HPV",
        vaccine_and_method: "HPV vaccine",
        vaccine_side_effects: ""
      )
    end
  end

  context "with a patient in primary school" do
    let(:date_of_birth) { Date.new(2015, 2, 1) }
    let(:patient) { create(:patient, date_of_birth:) }

    context "when it's an MMR programme and patient is eligible for MMRV" do
      let(:programmes) { [Programme.mmr] }
      let(:date_of_birth) { Programme::MIN_MMRV_ELIGIBILITY_DATE + 1.month }

      it { should have_attributes(vaccination: "MMRV vaccination") }

      it do
        expect(vaccination_details_presenter).to have_attributes(
          vaccination_and_dates_sms: "MMRV vaccination"
        )
      end
    end
  end

  context "with multiple programmes" do
    let(:programmes) { [Programme.menacwy, Programme.td_ipv] }

    it do
      expect(
        vaccination_details_presenter.vaccination
      ).to eq "MenACWY and Td/IPV (3-in-1 teenage booster) vaccinations"
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

      it { should have_attributes(vaccination: "MMR vaccination") }

      context "when receiving their first dose" do
        let(:vaccination_record) do
          create(
            :vaccination_record,
            :administered,
            programme: programmes.first,
            patient:,
            session:,
            performed_at: Date.new(2020, 1, 1)
          )
        end

        it { should have_attributes(vaccination: "MMR vaccination") }
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
        expect(vaccination_details_presenter).to have_attributes(
          vaccination: "HPV vaccination",
          vaccination_and_dates: "HPV vaccination"
        )
      end
    end
  end

  context "with an administered vaccination record" do
    let(:vaccine) { Vaccine.find_by!(brand: "Gardasil 9") }

    let(:vaccination_record) do
      create(
        :vaccination_record,
        :administered,
        programme: programmes.first,
        dose_sequence: 1,
        patient:,
        performed_at: Date.new(2024, 1, 1),
        vaccine:
      )
    end

    it do
      expect(vaccination_details_presenter).to have_attributes(
        vaccine_and_dose: "HPV 1st dose"
      )
    end
  end

  context "with a not-administered vaccination record" do
    let(:vaccination_record) do
      create(
        :vaccination_record,
        :not_administered,
        programme: programmes.first,
        performed_at: Date.new(2024, 1, 1)
      )
    end

    it do
      expect(vaccination_details_presenter).to have_attributes(
        reason_did_not_vaccinate: "the nurse decided John was not well"
      )
    end
  end

  context "with vaccine methods" do
    let(:personalisation) do
      GovukNotifyPersonalisation.new(
        patient:,
        session:,
        programme_types: programmes.map(&:type)
      )
    end

    context "and an injection-only programme" do
      before do
        create(
          :patient_programme_status,
          :due_injection,
          patient:,
          academic_year: session.academic_year,
          programme: programmes.first
        )
      end

      it do
        expect(
          vaccination_details_presenter.vaccine_is?("injection")
        ).to be true
      end

      it do
        expect(vaccination_details_presenter.vaccine_is?("nasal")).to be false
      end
    end

    context "and a nasal spray programme" do
      let(:programmes) { [Programme.flu] }

      before do
        create(
          :patient_programme_status,
          :due_nasal_injection,
          patient:,
          programme: programmes.first,
          academic_year: session.academic_year
        )
      end

      it do
        expect(
          vaccination_details_presenter.vaccine_is?("injection")
        ).to be false
      end

      it do
        expect(vaccination_details_presenter.vaccine_is?("nasal")).to be true
      end
    end

    context "and multiple programmes" do
      let(:programmes) { [hpv_programme, flu_programme] }

      before do
        create(
          :patient_programme_status,
          :due_nasal_injection,
          patient:,
          programme: flu_programme,
          academic_year: session.academic_year
        )
        create(
          :patient_programme_status,
          :due_injection,
          patient:,
          programme: hpv_programme,
          academic_year: session.academic_year
        )
      end

      it do
        expect(
          vaccination_details_presenter.vaccine_is?("injection")
        ).to be true
      end

      it do
        expect(vaccination_details_presenter.vaccine_is?("nasal")).to be true
      end
    end
  end

  context "with vaccine side effects" do
    before do
      Vaccine
        .for_programme(hpv_programme)
        .each { it.update!(side_effects: %w[swelling unwell]) }
    end

    it { should have_attributes(vaccine_side_effects: "") }

    context "with injection as an approved vaccine method" do
      before do
        create(
          :patient_programme_status,
          :due_injection,
          patient:,
          programme: hpv_programme,
          academic_year: session.academic_year
        )
      end

      it do
        expect(vaccination_details_presenter).to have_attributes(
          vaccine_side_effects:
            "- generally feeling unwell\n- swelling or pain where the injection was given"
        )
      end
    end
  end

  context "with a programme that has a different name on NHS.uk" do
    let(:programmes) { [Programme.td_ipv] }

    it do
      expect(vaccination_details_presenter).to have_attributes(
        vaccination: "Td/IPV (3-in-1 teenage booster) vaccination",
        vaccine: "Td/IPV (3-in-1 teenage booster) vaccine"
      )
    end
  end

  context "with the flu programme" do
    let(:programmes) { [Programme.flu] }

    it do
      expect(vaccination_details_presenter).to have_attributes(
        vaccination: "flu vaccination",
        vaccination_and_method: "flu vaccination",
        vaccine: "flu vaccine",
        vaccine_and_method: "flu vaccine"
      )
    end

    context "with an administered injected vaccination record" do
      let(:vaccination_record) do
        vaccine = programmes.first.vaccines.find_by!(method: "injection")
        create(
          :vaccination_record,
          patient:,
          programme: programmes.first,
          vaccine:
        )
      end

      it do
        expect(vaccination_details_presenter).to have_attributes(
          vaccination: "flu vaccination",
          vaccination_and_method: "injected flu vaccination",
          vaccine: "flu vaccine",
          vaccine_and_method: "injected flu vaccine"
        )
      end
    end

    context "with an administered nasal spray vaccination record" do
      let(:vaccination_record) do
        vaccine = programmes.first.vaccines.find_by!(method: "nasal")
        create(
          :vaccination_record,
          patient:,
          programme: programmes.first,
          vaccine:,
          delivery_method: "nasal_spray"
        )
      end

      it do
        expect(vaccination_details_presenter).to have_attributes(
          vaccination: "flu vaccination",
          vaccination_and_method: "nasal spray flu vaccination",
          vaccine: "flu vaccine",
          vaccine_and_method: "nasal spray flu vaccine"
        )
      end
    end
  end
end
