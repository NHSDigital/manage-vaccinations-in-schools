# frozen_string_literal: true

describe PatientMerger do
  describe "#call" do
    subject(:call) do
      # Intentionally call this method as we would in a controller because
      # we were finding bugs when called like this but not on its own.
      Audited
        .audit_class
        .as_user(user) do
          described_class.call(
            to_keep:
              Patient.includes(parent_relationships: :parent).find(
                patient_to_keep.id
              ),
            to_destroy:
              Patient.includes(parent_relationships: :parent).find(
                patient_to_destroy.id
              ),
            user:
          )
        end
    end

    let(:user) { create(:user) }

    let(:programme) { Programme.hpv }
    let(:team) { create(:team, programmes: [programme]) }
    let(:session) { create(:session, team:, programmes: [programme]) }

    let!(:patient_to_keep) { create(:patient, year_group: 8) }
    let!(:patient_to_destroy) { create(:patient, year_group: 8) }

    let(:access_log_entry) do
      create(:access_log_entry, patient: patient_to_destroy)
    end
    let(:attendance_record) do
      create(:attendance_record, :present, patient: patient_to_destroy)
    end
    let(:clinic_notification) do
      create(
        :clinic_notification,
        :initial_invitation,
        patient: patient_to_destroy,
        session:
      )
    end
    let(:consent) { create(:consent, patient: patient_to_destroy, programme:) }
    let(:consent_notification) do
      create(
        :consent_notification,
        :request,
        patient: patient_to_destroy,
        session:
      )
    end
    let(:gillick_assessment) do
      create(:gillick_assessment, :competent, patient: patient_to_destroy)
    end
    let(:note) { create(:note, patient: patient_to_destroy) }
    let(:notify_log_entry) do
      create(:notify_log_entry, :email, patient: patient_to_destroy)
    end
    let(:pds_search_result) do
      create(:pds_search_result, patient: patient_to_destroy)
    end
    let(:parent_relationship) do
      create(:parent_relationship, patient: patient_to_destroy)
    end
    let(:patient_location) do
      create(:patient_location, session:, patient: patient_to_destroy)
    end
    let(:patient_change_log_entry) do
      create(:patient_change_log_entry, patient: patient_to_destroy)
    end
    let(:patient_merge_log_entry) do
      create(:patient_merge_log_entry, patient: patient_to_destroy)
    end
    let(:patient_specific_direction) do
      create(
        :patient_specific_direction,
        programme:,
        patient: patient_to_destroy
      )
    end
    let(:patient_programme_vaccinations_search) do
      create(
        :patient_programme_vaccinations_search,
        patient: patient_to_destroy,
        programme: programme
      )
    end
    let(:pre_screening) { create(:pre_screening, patient: patient_to_destroy) }
    let(:school_move) do
      create(:school_move, :to_school, patient: patient_to_destroy)
    end
    let(:school_move_log_entry) do
      create(:school_move_log_entry, patient: patient_to_destroy)
    end
    let(:session_notification) do
      create(
        :session_notification,
        :school_reminder,
        patient: patient_to_destroy
      )
    end
    let(:triage) do
      create(
        :triage,
        :safe_to_vaccinate,
        patient: patient_to_destroy,
        programme:
      )
    end
    let(:vaccination_record) do
      create(
        :vaccination_record,
        patient: patient_to_destroy,
        session:,
        programme:
      )
    end
    let(:discarded_vaccination_record) do
      create(
        :vaccination_record,
        :discarded,
        patient: patient_to_destroy,
        session:,
        programme:
      )
    end

    it "destroys one of the patients" do
      expect { call }.to change(Patient, :count).by(-1)
      expect { patient_to_destroy.reload }.to raise_error(
        ActiveRecord::RecordNotFound
      )
    end

    it "moves access log entries" do
      expect { call }.to change { access_log_entry.reload.patient }.to(
        patient_to_keep
      )
    end

    it "moves attendance records" do
      expect { call }.to change { attendance_record.reload.patient }.to(
        patient_to_keep
      )
    end

    it "moves clinic notifications" do
      expect { call }.to change { clinic_notification.reload.patient }.to(
        patient_to_keep
      )
    end

    it "moves consents" do
      expect { call }.to change { consent.reload.patient }.to(patient_to_keep)
    end

    it "moves consent notifications" do
      expect { call }.to change { consent_notification.reload.patient }.to(
        patient_to_keep
      )
    end

    it "moves gillick assessments" do
      expect { call }.to change { gillick_assessment.reload.patient }.to(
        patient_to_keep
      )
    end

    it "moves notes" do
      expect { call }.to change { note.reload.patient }.to(patient_to_keep)
    end

    it "moves notify log entries" do
      expect { call }.to change { notify_log_entry.reload.patient }.to(
        patient_to_keep
      )
    end

    it "moves PDS search results" do
      expect { call }.to change { pds_search_result.reload.patient }.to(
        patient_to_keep
      )
    end

    it "moves parent relationships" do
      expect { call }.to change { parent_relationship.reload.patient }.to(
        patient_to_keep
      )
    end

    it "moves patient change log entries" do
      expect { call }.to change { patient_change_log_entry.reload.patient }.to(
        patient_to_keep
      )
    end

    it "moves patient merge log entries" do
      expect { call }.to change { patient_merge_log_entry.reload.patient }.to(
        patient_to_keep
      )
    end

    it "moves patient locations" do
      expect { call }.to change { patient_location.reload.patient }.to(
        patient_to_keep
      )
    end

    it "moves patient programme vaccinations searches" do
      expect { call }.to change {
        patient_programme_vaccinations_search.reload.patient
      }.to(patient_to_keep)
    end

    it "moves patient specific directions" do
      expect { call }.to change {
        patient_specific_direction.reload.patient
      }.to(patient_to_keep)
    end

    it "moves pre-screenings" do
      expect { call }.to change { pre_screening.reload.patient }.to(
        patient_to_keep
      )
    end

    it "moves school moves" do
      expect { call }.to change { school_move.reload.patient }.to(
        patient_to_keep
      )
    end

    it "moves school move log entries" do
      expect { call }.to change { school_move_log_entry.reload.patient }.to(
        patient_to_keep
      )
    end

    it "deletes duplicate school moves" do
      school_move # ensure school move on patient to destroy exists
      create(:school_move, :to_home_educated, patient: patient_to_keep)

      expect { call }.to change(SchoolMove, :count).by(-1)
      expect { school_move.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "moves session notifications" do
      expect { call }.to change { session_notification.reload.patient }.to(
        patient_to_keep
      )
    end

    it "moves triages" do
      expect { call }.to change { triage.reload.patient }.to(patient_to_keep)
    end

    it "moves vaccination records" do
      expect { call }.to change { vaccination_record.reload.patient }.to(
        patient_to_keep
      )
    end

    it "moves discarded vaccination records" do
      expect { call }.to change {
        discarded_vaccination_record.reload.patient
      }.to(patient_to_keep)
    end

    it "ensures the patient to keep is added to any teams" do
      team1 = create(:team)
      team2 = create(:team)

      create(
        :patient_team,
        patient: patient_to_destroy,
        team: team1,
        sources: %w[patient_location]
      )
      create(
        :patient_team,
        patient: patient_to_keep,
        team: team1,
        sources: %w[archive_reason]
      )
      create(
        :patient_team,
        patient: patient_to_destroy,
        team: team2,
        sources: %w[school_move_school]
      )

      expect { call }.to change(PatientTeam, :count).by(-1)

      expect(
        patient_to_keep.patient_teams.find_by(team: team1).sources
      ).to contain_exactly("archive_reason", "patient_location")
      expect(
        patient_to_keep.patient_teams.find_by(team: team2).sources
      ).to contain_exactly("school_move_school")
    end

    it "enqueues search job for kept patient" do
      expect { call }.to enqueue_sidekiq_job(
        SearchVaccinationRecordsInNHSJob
      ).with(patient_to_keep.id)
    end

    it "enqueues sync jobs for vaccination records" do
      Flipper.enable(:imms_api_sync_job, programme)
      expect { call }.to enqueue_sidekiq_job(
        SyncVaccinationRecordToNHSJob
      ).with(vaccination_record.id)
    end

    it "creates a patient merge log entry" do
      expect { call }.to change(PatientMergeLogEntry, :count).by(1)

      log_entry = PatientMergeLogEntry.last
      expect(log_entry.patient).to eq(patient_to_keep)
      expect(log_entry.merged_patient_id).to eq(patient_to_destroy.id)
      expect(log_entry.user).to eq(user)
    end

    context "when parent is already associated with patient to keep" do
      before do
        create(
          :parent_relationship,
          parent: parent_relationship.parent,
          patient: patient_to_keep
        )
      end

      it "destroys the relationship with the patient to destroy" do
        expect { call }.to change(ParentRelationship, :count).by(-1)
        expect { parent_relationship.reload }.to raise_error(
          ActiveRecord::RecordNotFound
        )
      end
    end

    context "when patient to keep is archived" do
      before do
        create(
          :archive_reason,
          :moved_out_of_area,
          patient: patient_to_keep,
          team:
        )
      end

      it "removes the archive reasons from the patient" do
        expect { call }.to change(ArchiveReason, :count).by(-1)
        expect(patient_to_keep.archived?(team_id: team.id)).to be(false)
      end
    end

    context "when patient to destroy is archived" do
      before do
        create(
          :archive_reason,
          :moved_out_of_area,
          patient: patient_to_destroy,
          team:
        )
      end

      it "removes the archive reason from the patient" do
        expect { call }.to change(ArchiveReason, :count).by(-1)
        expect(patient_to_keep.archived?(team_id: team.id)).to be(false)
      end
    end

    context "when both patients have attendance records" do
      let!(:to_keep_attendance_record) do
        create(
          :attendance_record,
          :present,
          patient: patient_to_keep,
          location_id: attendance_record.location_id,
          date: attendance_record.date,
          session: nil
        )
      end

      it "keeps the attendance record on the merged patient" do
        expect { call }.to change(AttendanceRecord, :count).by(-1)
        expect { attendance_record.reload }.to raise_error(
          ActiveRecord::RecordNotFound
        )
        expect(to_keep_attendance_record.reload.patient).to eq(patient_to_keep)
      end
    end

    context "when both patients are archived" do
      before do
        create(
          :archive_reason,
          :moved_out_of_area,
          patient: patient_to_keep,
          team:
        )
        create(
          :archive_reason,
          :moved_out_of_area,
          patient: patient_to_destroy,
          team:
        )
      end

      it "keeps the archive reason on the merged patient" do
        expect { call }.to change(ArchiveReason, :count).by(-1)
        expect(patient_to_keep.archived?(team_id: team.id)).to be(true)
      end
    end

    describe "vaccination searches" do
      context "when patients have overlapping and unique programme searches" do
        before do
          create(
            :patient_programme_vaccinations_search,
            patient: patient_to_keep,
            programme: Programme.hpv,
            last_searched_at: 1.day.ago
          )
          create(
            :patient_programme_vaccinations_search,
            patient: patient_to_destroy,
            programme: Programme.hpv,
            last_searched_at: 5.days.ago
          )

          create(
            :patient_programme_vaccinations_search,
            patient: patient_to_destroy,
            programme: Programme.flu,
            last_searched_at: 3.days.ago
          )
          create(
            :patient_programme_vaccinations_search,
            patient: patient_to_keep,
            programme: Programme.flu,
            last_searched_at: 1.day.ago
          )

          create(
            :patient_programme_vaccinations_search,
            patient: patient_to_keep,
            programme: Programme.menacwy,
            last_searched_at: 2.days.ago
          )

          create(
            :patient_programme_vaccinations_search,
            patient: patient_to_destroy,
            programme: Programme.td_ipv,
            last_searched_at: 2.days.ago
          )
        end

        it "merges searches correctly" do
          expect { call }.to change(
            PatientProgrammeVaccinationsSearch,
            :count
          ).by(-2)

          searches = patient_to_keep.patient_programme_vaccinations_searches
          expect(searches.count).to eq(4)

          hpv_search = searches.find_by(programme_type: "hpv")
          expect(hpv_search.last_searched_at.to_date).to eq(1.day.ago.to_date)

          flu_search = searches.find_by(programme_type: "flu")
          expect(flu_search.last_searched_at.to_date).to eq(1.day.ago.to_date)

          tdipv_search = searches.find_by(programme_type: "td_ipv")
          expect(tdipv_search.last_searched_at.to_date).to eq(
            2.days.ago.to_date
          )

          menacwy_search = searches.find_by(programme_type: "menacwy")
          expect(menacwy_search.last_searched_at.to_date).to eq(
            2.days.ago.to_date
          )
        end
      end
    end

    context "when the patient to destroy has a changeset" do
      before do
        create(:patient_changeset, :class_import, patient: patient_to_destroy)
      end

      it "unassigns the changeset from the patient" do
        expect { call }.not_to change(PatientChangeset, :count)
        expect(patient_to_keep.changesets).to be_empty
      end
    end
  end
end
