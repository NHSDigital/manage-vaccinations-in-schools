# frozen_string_literal: true

describe API::Testing::TeamsController do
  include ActiveJob::TestHelper
  include ImportsHelper

  before { Flipper.enable(:testing_api) }
  after { Flipper.disable(:testing_api) }

  around { |example| travel_to(Date.new(2025, 7, 31)) { example.run } }

  describe "DELETE" do
    let(:programmes) { [Programme.hpv] }

    let(:team) { create(:team, ods_code: "R1L", workgroup: "r1l", programmes:) }

    let(:cohort_import) do
      create(
        :cohort_import,
        csv_data: file_fixture("cohort_import/valid.csv").read,
        team:
      )
    end

    let(:immunisation_import) do
      create(
        :immunisation_import,
        csv_data:
          file_fixture("immunisation_import/point_of_care/valid_hpv.csv").read,
        team:
      )
    end

    before do
      create(:subteam, team:)

      programmes.each do |programme|
        programme.vaccines.each do |vaccine|
          create_list(:batch, 4, team:, vaccine:)
        end
      end

      create(:gias_school, urn: "123456", team:, programmes:) # to match cohort_import/valid.csv
      create(:gias_school, urn: "110158", team:, programmes:) # to match valid_hpv.csv

      session =
        create(:session, team:, location: team.gias_schools.first, programmes:)

      process_and_approve_import(cohort_import)
      immunisation_import.process!

      Patient.find_each do |patient|
        create(:notify_log_entry, :email, patient:, consent_form: nil)

        consent_form = create(:consent_form, session:)
        parent =
          patient.parents.first || create(:parent_relationship, patient:).parent
        create(
          :consent,
          :given,
          patient:,
          parent:,
          consent_form:,
          programme: programmes.first
        )
      end

      create(:school_move, :to_school, patient: Patient.first)
      create(:pre_screening, patient: Patient.first, session:)
    end

    context "when not keeping itself" do
      subject(:call) { delete :destroy, params: { workgroup: "r1l" } }

      it "deletes associated data" do
        expect { call }.to(
          change(Team, :count)
            .by(-1)
            .and(change(Subteam, :count).by(-1))
            .and(change(Session, :count).by(-1))
            .and(change(CohortImport, :count).by(-1))
            .and(change(ImmunisationImport, :count).by(-1))
            .and(change(NotifyLogEntry, :count).by(-13))
            .and(change(Parent, :count).by(-14))
            .and(change(Patient, :count).by(-13))
            .and(change(PatientLocation, :count).by(-3))
            .and(change(VaccinationRecord, :count).by(-11))
        )
      end

      it_behaves_like "a method that updates team cached counts"
    end

    context "when keeping itself" do
      subject(:call) do
        delete :destroy, params: { workgroup: "r1l", keep_itself: "true" }
      end

      it "deletes associated data" do
        expect { call }.to(
          not_change(Team, :count)
            .and(not_change(Subteam, :count))
            .and(change(Session, :count).by(-1))
            .and(change(CohortImport, :count).by(-1))
            .and(change(ImmunisationImport, :count).by(-1))
            .and(change(NotifyLogEntry, :count).by(-13))
            .and(change(Parent, :count).by(-14))
            .and(change(Patient, :count).by(-13))
            .and(change(PatientLocation, :count).by(-3))
            .and(change(VaccinationRecord, :count).by(-11))
        )
      end

      it_behaves_like "a method that updates team cached counts"
    end
  end
end
