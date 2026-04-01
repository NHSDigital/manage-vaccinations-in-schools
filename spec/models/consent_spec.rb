# frozen_string_literal: true

# == Schema Information
#
# Table name: consents
#
#  id                                              :bigint           not null, primary key
#  academic_year                                   :integer          not null
#  disease_types                                   :enum             not null, is an Array
#  follow_up_outcome                               :integer
#  follow_up_requested                             :boolean
#  follow_up_resolved_at                           :datetime
#  health_answers                                  :jsonb            not null
#  invalidated_at                                  :datetime
#  notes                                           :text             default(""), not null
#  notify_parent_on_refusal                        :boolean
#  notify_parents_on_vaccination                   :boolean
#  parent_email                                    :string
#  parent_full_name                                :string
#  parent_phone                                    :string
#  parent_phone_receive_updates                    :boolean
#  parent_relationship_other_name                  :string
#  parent_relationship_type                        :string
#  patient_already_vaccinated_notification_sent_at :datetime
#  programme_type                                  :enum             not null
#  reason_for_refusal                              :integer
#  response                                        :integer          not null
#  route                                           :integer          not null
#  submitted_at                                    :datetime         not null
#  vaccine_methods                                 :integer          default([]), not null, is an Array
#  withdrawn_at                                    :datetime
#  without_gelatine                                :boolean
#  created_at                                      :datetime         not null
#  updated_at                                      :datetime         not null
#  consent_form_id                                 :bigint
#  parent_id                                       :bigint
#  patient_id                                      :bigint           not null
#  recorded_by_user_id                             :bigint
#  team_id                                         :bigint           not null
#
# Indexes
#
#  index_consents_on_academic_year        (academic_year)
#  index_consents_on_consent_form_id      (consent_form_id)
#  index_consents_on_parent_id            (parent_id)
#  index_consents_on_patient_id           (patient_id)
#  index_consents_on_programme_type       (programme_type)
#  index_consents_on_recorded_by_user_id  (recorded_by_user_id)
#  index_consents_on_team_id              (team_id)
#
# Foreign Keys
#
#  fk_rails_...  (consent_form_id => consent_forms.id)
#  fk_rails_...  (parent_id => parents.id)
#  fk_rails_...  (patient_id => patients.id)
#  fk_rails_...  (recorded_by_user_id => users.id)
#  fk_rails_...  (team_id => teams.id)
#

describe Consent do
  subject(:consent) { build(:consent) }

  describe "associations" do
    it { should belong_to(:consent_form).optional(true) }
  end

  describe "validations" do
    it { should validate_length_of(:notes).is_at_most(1000) }

    context "when response is given" do
      subject { build(:consent, :given) }

      it { should validate_presence_of(:vaccine_methods) }
    end

    context "when response is refused" do
      subject { build(:consent, :refused) }

      it { should_not validate_presence_of(:vaccine_methods) }
      it { should_not validate_presence_of(:without_gelatine) }
    end
  end

  describe "#verbal_routes" do
    subject(:verbal_routes) { described_class.verbal_routes }

    it "does not include online or self-consent do" do
      expect(verbal_routes.keys).to match_array(%w[phone paper in_person])
    end
  end

  describe "when consent given by parent or guardian, all health questions are no" do
    it "does not require triage" do
      response = build(:consent, :given)

      expect(response).not_to be_requires_triage
    end
  end

  describe "when consent given by parent or guardian, but some info provided in the health questions" do
    it "does require triage" do
      health_answers = [
        HealthAnswer.new(
          question:
            "Does the child have a disease or treatment that severely affects their immune system?",
          response: "yes"
        )
      ]
      response = build(:consent, :given, health_answers:)

      expect(response).to be_requires_triage
    end
  end

  describe "#responded_at" do
    subject(:responded_at) { consent.responded_at }

    let(:consent) do
      build(:consent, submitted_at: Time.zone.local(2024, 12, 20, 12))
    end

    it { should eq(Time.zone.local(2024, 12, 20, 12)) }
  end

  describe "#from_consent_form!" do
    context "with on programme" do
      subject(:consent) do
        described_class.from_consent_form!(
          consent_form,
          patient:,
          current_user:
        ).first
      end

      let(:consent_form) do
        create(:consent_form, :recorded, reason_for_refusal_notes: "")
      end
      let(:patient) { create(:patient) }
      let(:current_user) { create(:user) }

      it "sets who matched the consent" do
        expect(consent.recorded_by).to eq(current_user)
      end

      it "copies over attributes from consent form" do
        consent_form_programme = consent_form.consent_form_programmes.first
        expect(consent).to(
          have_attributes(
            programme_type: consent_form_programme.programme_type,
            patient:,
            consent_form:,
            reason_for_refusal: consent_form.reason_for_refusal,
            notes: "",
            response: "given",
            route: "website",
            disease_types: consent_form_programme.programme.disease_types
          )
        )
      end

      it "saves parent details to the consent" do
        expect(consent).to have_attributes(
          parent_full_name: consent_form.parent_full_name,
          parent_email: consent_form.parent_email,
          parent_phone: consent_form.parent_phone,
          parent_phone_receive_updates:
            consent_form.parent_phone_receive_updates,
          parent_relationship_type: consent_form.parent_relationship_type,
          parent_relationship_other_name:
            consent_form.parent_relationship_other_name
        )
      end

      it "creates a parent" do
        expect(consent.parent).to have_attributes(
          contact_method_other_details:
            consent_form.parent_contact_method_other_details,
          contact_method_type: consent_form.parent_contact_method_type,
          email: consent_form.parent_email,
          full_name: consent_form.parent_full_name,
          phone: consent_form.parent_phone,
          phone_receive_updates: consent_form.parent_phone_receive_updates
        )
      end

      it "copies health answers from consent_form" do
        expect(consent.health_answers.to_json).to eq(
          consent_form.health_answers.to_json
        )
      end

      context "with an existing parent" do
        let(:parent) do
          create(:parent, full_name: consent_form.parent_full_name)
        end

        before { create(:parent_relationship, patient:, parent:) }

        it "re-uses the same parent" do
          expect(consent.parent).to eq(parent)
          expect(consent.parent).to have_attributes(
            full_name: consent_form.parent_full_name,
            email: consent_form.parent_email,
            phone: Phonelib.parse(consent_form.parent_phone).national,
            phone_receive_updates: consent_form.parent_phone_receive_updates
          )
        end
      end

      context "when consenting to nasal spray" do
        before do
          consent_form.consent_form_programmes.first.update!(
            vaccine_methods: %w[nasal]
          )
        end

        it "stores this preference on the consent" do
          expect(consent.vaccine_methods).to contain_exactly("nasal")
        end
      end
    end

    context "with multiple programmes" do
      subject(:consents) do
        described_class.from_consent_form!(
          consent_form,
          patient:,
          current_user:
        )
      end

      let(:programmes) { [Programme.menacwy, Programme.td_ipv] }
      let(:patient) { create(:patient) }
      let(:current_user) { create(:user) }
      let(:team) { create(:team, programmes:) }
      let(:session) { create(:session, team:, programmes:) }
      let(:consent_form) { create(:consent_form, :recorded, session:) }

      before do
        consent_form.consent_form_programmes.first.update!(
          response: "given",
          vaccine_methods: %w[injection]
        )
        consent_form.consent_form_programmes.second.update!(
          response: "refused",
          vaccine_methods: [],
          reason_for_refusal: "personal_choice",
          notes: "Personal reasons."
        )
      end

      it "creates a consent per programme" do
        expect(consents.map(&:programme)).to eq(programmes)
      end

      it "creates consent given for MenACWY" do
        expect(consents.first).to have_attributes(
          programme: programmes.first,
          patient:,
          consent_form:,
          reason_for_refusal: nil,
          notes: "",
          response: "given",
          route: "website"
        )
      end

      it "creates consent refused for Td/IPV" do
        expect(consents.second).to have_attributes(
          programme: programmes.second,
          patient:,
          consent_form:,
          reason_for_refusal: "personal_choice",
          notes: "Personal reasons.",
          response: "refused",
          route: "website"
        )
      end
    end
  end

  it "resets health answer notes if a 'yes' changes to a 'no'" do
    consent =
      build(:consent, :given, :health_question_notes, parent: create(:parent))
    expect(consent.health_answers.last.response).to eq("yes")
    expect(consent.health_answers.last.notes).to be_present

    param =
      ActionController::Parameters.new(
        { "notes" => "Some notes", "response" => "no" }
      )
    param.permit!

    consent.health_answers.last.assign_attributes(param)
    consent.save!
    consent.reload

    expect(consent.health_answers.last.response).to eq("no")
    expect(consent.health_answers.last.notes).to be_nil
  end

  describe "#for_academic_year" do
    let(:current_academic_year) { AcademicYear.current }
    let(:previous_academic_year) { current_academic_year - 1 }
    let(:next_academic_year) { current_academic_year + 1 }

    let(:patient) { create(:patient) }
    let(:programme) { Programme.sample }
    let(:parent) { create(:parent) }

    let!(:consent_current_year_start) do
      create(
        :consent,
        patient:,
        programme:,
        parent: parent,
        submitted_at: Date.new(current_academic_year, 9, 1).in_time_zone,
        academic_year: current_academic_year
      )
    end

    let!(:consent_current_year_middle) do
      create(
        :consent,
        patient: create(:patient),
        programme:,
        parent: parent,
        submitted_at: Date.new(current_academic_year + 1, 1, 15).in_time_zone,
        academic_year: current_academic_year
      )
    end

    let!(:consent_current_year_end) do
      create(
        :consent,
        patient: create(:patient),
        programme:,
        parent: parent,
        submitted_at: Date.new(current_academic_year + 1, 8, 31).in_time_zone,
        academic_year: current_academic_year
      )
    end

    let!(:consent_previous_year) do
      create(
        :consent,
        patient: create(:patient),
        programme:,
        parent: parent,
        submitted_at: Date.new(previous_academic_year, 10, 15).in_time_zone,
        academic_year: previous_academic_year
      )
    end

    let!(:consent_next_year) do
      create(
        :consent,
        patient: create(:patient),
        programme:,
        parent: parent,
        submitted_at: Date.new(next_academic_year, 10, 15).in_time_zone,
        academic_year: next_academic_year
      )
    end

    it "returns consents for the specified academic year" do
      consents = described_class.where(academic_year: current_academic_year)

      expect(consents).to include(consent_current_year_start)
      expect(consents).to include(consent_current_year_middle)
      expect(consents).to include(consent_current_year_end)
      expect(consents).not_to include(consent_previous_year)
      expect(consents).not_to include(consent_next_year)
    end
  end

  describe "#update_vaccination_records_no_notify" do
    let(:patient) { create(:patient) }
    let(:programme) { Programme.hpv }
    let(:consent) { create(:consent, patient:, programme:) }

    context "when vaccination records exist for the patient and programme" do
      let!(:first_vaccination_record) do
        create(:vaccination_record, patient:, programme:, notify_parents: false)
      end
      let!(:second_vaccination_record) do
        create(:vaccination_record, patient:, programme:, notify_parents: true)
      end
      let!(:other_patient_record) do
        create(
          :vaccination_record,
          patient: create(:patient),
          programme:,
          notify_parents: false
        )
      end
      let!(:other_programme_record) do
        create(
          :vaccination_record,
          patient:,
          programme: Programme.flu,
          notify_parents: false
        )
      end

      before do
        allow(VaccinationNotificationCriteria).to receive(:call).with(
          vaccination_record: first_vaccination_record
        ).and_return(true)
        allow(VaccinationNotificationCriteria).to receive(:call).with(
          vaccination_record: second_vaccination_record
        ).and_return(false)
      end

      it "updates notify_parents for matching vaccination records" do
        expect { consent.update_vaccination_records_no_notify! }.to change {
          first_vaccination_record.reload.notify_parents
        }.from(false).to(true).and change {
                second_vaccination_record.reload.notify_parents
              }.from(true).to(false)
      end

      it "does not update vaccination records for other patients" do
        expect { consent.update_vaccination_records_no_notify! }.not_to(
          change { other_patient_record.reload.notify_parents }
        )
      end

      it "does not update vaccination records for other programmes" do
        expect { consent.update_vaccination_records_no_notify! }.not_to(
          change { other_programme_record.reload.notify_parents }
        )
      end

      it "calls VaccinationNotificationCriteria for each matching record" do
        consent.update_vaccination_records_no_notify!

        expect(VaccinationNotificationCriteria).to have_received(:call).with(
          vaccination_record: first_vaccination_record
        )
        expect(VaccinationNotificationCriteria).to have_received(:call).with(
          vaccination_record: second_vaccination_record
        )
      end
    end

    context "with multiple vaccination records and mixed results" do
      let!(:vaccination_records) do
        create_list(
          :vaccination_record,
          3,
          patient:,
          programme:,
          notify_parents: false
        )
      end

      before do
        allow(VaccinationNotificationCriteria).to receive(:call).with(
          vaccination_record: vaccination_records[0]
        ).and_return(true)
        allow(VaccinationNotificationCriteria).to receive(:call).with(
          vaccination_record: vaccination_records[1]
        ).and_return(nil)
        allow(VaccinationNotificationCriteria).to receive(:call).with(
          vaccination_record: vaccination_records[2]
        ).and_return(false)
      end

      it "updates each vaccination record according to the criteria result" do
        expect { consent.update_vaccination_records_no_notify! }.to change {
          vaccination_records[0].reload.notify_parents
        }.from(false).to(true).and change {
                vaccination_records[1].reload.notify_parents
              }
                .from(false)
                .to(nil)
                .and(
                  not_change { vaccination_records[2].reload.notify_parents }
                )
      end
    end
  end

  describe "#resolve_follow_up!" do
    let(:patient) { create(:patient) }
    let(:consent) { create(:consent, patient:, notes: "Existing notes") }

    before { allow(PatientStatusUpdater).to receive(:call) }

    context "when confirming refusal with notes" do
      it "updates follow-up fields and overwrites notes" do
        freeze_time do
          expect {
            consent.resolve_follow_up!(outcome: :confirmed, notes: "New notes")
          }.to change { consent.reload.follow_up_outcome }.to(
            "confirmed"
          ).and change(consent, :follow_up_requested).to(false).and change(
                        consent,
                        :follow_up_resolved_at
                      ).to(Time.current).and change(consent, :notes).to(
                              "New notes"
                            )
        end

        expect(PatientStatusUpdater).to have_received(:call).with(patient:)
      end
    end

    context "when no notes are provided" do
      it "does not overwrite existing notes" do
        expect { consent.resolve_follow_up!(outcome: :confirmed) }.not_to(
          change { consent.reload.notes }
        )
      end
    end

    context "when invalidate is true" do
      it "sets invalidated_at" do
        freeze_time do
          expect {
            consent.resolve_follow_up!(outcome: :withdrawn, invalidate: true)
          }.to change { consent.reload.invalidated_at }.to(Time.current)
        end
      end
    end
  end
end
