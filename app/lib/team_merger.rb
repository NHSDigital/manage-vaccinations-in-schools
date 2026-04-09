# frozen_string_literal: true

class TeamMerger
  Error = Class.new(StandardError)

  SIMPLE_MODELS = [
    ClassImport,
    ClinicNotification,
    CohortImport,
    Consent,
    ImmunisationImport,
    PatientSpecificDirection,
    SchoolMoveLogEntry,
    Triage
  ].freeze

  attr_reader :source_teams, :new_team_attrs, :errors, :dry_run_report

  ## Initializes a merger for the given source teams and attributes for the new
  # team that will replace them.
  #
  # The +source_teams+ attribute is a list of the teams to be merged.
  #
  # The +new_team_attrs+ hash is used to create the merged team, and should
  # contain all attributes necessary to create a new team.
  def initialize(source_teams:, new_team_attrs:)
    @source_teams = source_teams
    @new_team_attrs = new_team_attrs
  end

  def valid?
    @errors = []
    validate_minimum_teams
    validate_same_organisation
    validate_same_type
    detect_subteam_conflicts
    detect_team_location_conflicts
    @errors.empty?
  end

  def dry_run
    @dry_run_report = []
    append_migration_counts
    append_batch_skips
    append_archive_reason_merges

    if valid?
      @dry_run_report << "Merge would succeed."
    else
      @dry_run_report << "Merge would ABORT with #{@errors.size} error(s):"
      @dry_run_report += @errors.map { "  ERROR: #{it}" }
    end

    @dry_run_report
  end

  def call!
    raise Error, @errors.join("; ") unless valid?

    result =
      ActiveRecord::Base.transaction do
        merged_team = Team.create!(new_team_attrs)

        migrate_simple_tables(merged_team)
        migrate_batches(merged_team)
        migrate_archive_reasons(merged_team)
        migrate_important_notices(merged_team)
        migrate_subteams(merged_team)
        migrate_generic_locations(merged_team)
        migrate_team_locations(merged_team)
        migrate_teams_users(merged_team)

        Rails.logger.debug "Migrating patients..."
        PatientTeamUpdater.call(
          team_scope:
            Team.where(id: source_teams.map(&:id)).or(
              Team.where(id: merged_team.id)
            )
        )

        Rails.logger.debug "Destroying old teams..."
        source_teams.each(&:destroy!)
        merged_team
      end

    refresh_materialized_views
    result
  end

  private

  def validate_minimum_teams
    if source_teams.size < 2
      @errors << "At least two source teams are required."
    end
  end

  def validate_same_organisation
    return if source_teams.map(&:organisation_id).uniq.size == 1

    @errors << "Teams belong to different organisations: " \
      "#{source_teams.map { "#{it.workgroup}(org #{it.organisation_id})" }.join(", ")}"
  end

  def validate_same_type
    return if source_teams.map(&:type).uniq.size == 1

    @errors << "Teams have different types: " \
      "#{source_teams.map { "#{it.workgroup}(#{it.type})" }.join(", ")}"
  end

  def source_team_ids
    @source_team_ids ||= source_teams.map(&:id)
  end

  def source_teams_by_id
    @source_teams_by_id ||= source_teams.index_by(&:id)
  end

  def active_in_some_source_team_ids
    @active_in_some_source_team_ids ||=
      PatientTeam
        .where(team_id: source_team_ids)
        .joins(
          "LEFT JOIN archive_reasons ON archive_reasons.patient_id = patient_teams.patient_id
                                       AND archive_reasons.team_id = patient_teams.team_id"
        )
        .where("archive_reasons.id IS NULL")
        .distinct
        .pluck(:patient_id)
  end

  def detect_subteam_conflicts
    all_names = source_teams.flat_map { it.subteams.pluck(:name) }
    all_names
      .tally
      .select { |_name, count| count > 1 }
      .each_key do |name|
        @errors << "Subteam '#{name}' exists in multiple source teams"
      end
  end

  def detect_team_location_conflicts
    TeamLocation
      .where(team_id: source_team_ids)
      .group(:academic_year, :location_id)
      .having(Arel.sql("COUNT(*) > 1"))
      .pluck(
        :location_id,
        :academic_year,
        Arel.sql("COUNT(DISTINCT COALESCE(subteam_id::text, 'NULL'))")
      )
      .each do |location_id, academic_year, subteam_variants|
        if subteam_variants > 1
          @errors << "Location #{location_id} (year #{academic_year}) " \
            "is assigned to different subteams across source teams"
        end
      end
  end

  def migrate_simple_tables(merged_team)
    Rails.logger.debug "Migrating simple tables..."

    SIMPLE_MODELS.each do |model|
      model.where(team_id: source_team_ids).update_all(team_id: merged_team.id)
    end
  end

  def migrate_batches(merged_team)
    Rails.logger.debug "Migrating batches..."

    keep_ids =
      Batch
        .where(team_id: source_team_ids)
        .group(:number, :expiry, :vaccine_id)
        .minimum(:id)
        .values
    Batch.where(team_id: source_team_ids).where.not(id: keep_ids).delete_all
    Batch.where(team_id: source_team_ids).update_all(team_id: merged_team.id)
  end

  def migrate_archive_reasons(merged_team)
    Rails.logger.debug "Migrating archive reasons..."

    patient_ids_with_reasons =
      ArchiveReason.where(team_id: source_team_ids).distinct.pluck(:patient_id)

    fully_archived = patient_ids_with_reasons - active_in_some_source_team_ids
    @patients_to_unarchive = patient_ids_with_reasons - fully_archived

    ArchiveReason.where(
      team_id: source_team_ids,
      patient_id: @patients_to_unarchive
    ).delete_all

    fully_archived.each do |patient_id|
      reasons =
        ArchiveReason
          .where(team_id: source_team_ids, patient_id:)
          .order(:id)
          .to_a

      type =
        if reasons.map(&:type).uniq.size == 1
          reasons.first.type
        else
          :other
        end

      merged_details =
        reasons.map do |archive_reason|
          detail =
            archive_reason.other? ? " (#{archive_reason.other_details})" : ""
          "#{source_teams_by_id[archive_reason.team_id].name}: #{archive_reason.type.humanize}#{detail}"
        end if type == :other

      ArchiveReason.create!(
        team_id: merged_team.id,
        patient_id: patient_id,
        type:,
        other_details: merged_details&.join("\n") || ""
      )

      ArchiveReason.where(id: reasons.map(&:id)).delete_all
    end
  end

  def migrate_important_notices(merged_team)
    Rails.logger.debug "Migrating important notices..."

    keep_ids =
      ImportantNotice
        .where(team_id: source_team_ids)
        .group(:patient_id, :type, :recorded_at)
        .minimum(:id)
        .values
    ImportantNotice
      .where(team_id: source_team_ids)
      .where.not(id: keep_ids)
      .delete_all
    ImportantNotice.where(team_id: source_team_ids).update_all(
      team_id: merged_team.id
    )
  end

  def migrate_subteams(merged_team)
    Rails.logger.debug "Migrating subteams..."

    Subteam.where(team_id: source_team_ids).update_all(team_id: merged_team.id)
  end

  def migrate_teams_users(merged_team)
    Rails.logger.debug "Migrating users..."

    sql = <<~SQL
      INSERT INTO teams_users (team_id, user_id)
      SELECT DISTINCT #{merged_team.id}, user_id
      FROM teams_users
      WHERE team_id IN (:team_ids)
      ON CONFLICT DO NOTHING
    SQL

    sanitized_sql =
      ActiveRecord::Base.sanitize_sql([sql, { team_ids: source_team_ids }])
    ActiveRecord::Base.connection.execute(sanitized_sql)
  end

  def migrate_team_locations(merged_team)
    Rails.logger.debug "Migrating team locations..."

    source_teams.each do |source_team|
      source_team.team_locations.find_each do |tl|
        previously_migrated_tl =
          TeamLocation.find_by(
            team_id: merged_team.id,
            academic_year: tl.academic_year,
            location_id: tl.location_id
          )
        if previously_migrated_tl.present?
          ConsentForm.where(team_location_id: tl.id).update_all(
            team_location_id: previously_migrated_tl.id
          )
          tl.destroy!
        else
          tl.update_columns(team_id: merged_team.id)
        end
      end
    end
  end

  def migrate_generic_locations(merged_team)
    Rails.logger.debug "Migrating generic locations..."

    source_gl_tl_ids =
      TeamLocation
        .joins(:location)
        .where(team_id: source_team_ids)
        .merge(Location.where(type: %i[generic_clinic generic_school]))
        .pluck(:id)

    source_gl_tls = TeamLocation.where(id: source_gl_tl_ids)
    academic_years = source_gl_tls.distinct.pluck(:academic_year)
    source_gl_location_ids = source_gl_tls.distinct.pluck(:location_id)

    academic_years.each do |year|
      GenericLocationFactory.call(team: merged_team.reload, academic_year: year)
    end
    merged_team.reload

    source_locations = Location.where(id: source_gl_location_ids).index_by(&:id)

    merged_loc_map =
      source_gl_location_ids.to_h do |loc_id|
        loc = source_locations[loc_id]
        merged_loc =
          if loc.generic_clinic?
            merged_team.generic_clinics.first
          else
            merged_team.generic_schools.find_by!(urn: loc.urn)
          end
        [loc_id, merged_loc]
      end

    source_gl_tls.find_each do |old_tl|
      merged_loc = merged_loc_map[old_tl.location_id]
      merged_tl =
        TeamLocation.find_by!(
          team: merged_team,
          location: merged_loc,
          academic_year: old_tl.academic_year
        )
      Session.where(team_location_id: old_tl.id).update_all(
        team_location_id: merged_tl.id
      )
      ConsentForm.where(team_location_id: old_tl.id).update_all(
        team_location_id: merged_tl.id
      )
      ConsentNotification.where(team_location_id: old_tl.id).update_all(
        team_location_id: merged_tl.id
      )
    end

    merged_loc_map
      .group_by { |_, merged_loc| merged_loc.id }
      .each_value do |pairs|
        source_ids = pairs.map(&:first)
        merged_loc = pairs.first.last

        [
          AttendanceRecord,
          GillickAssessment,
          PreScreening,
          VaccinationRecord
        ].each do |model|
          model.where(location_id: source_ids).update_all(
            location_id: merged_loc.id
          )
        end

        [
          ConsentForm,
          Patient,
          PatientChangeset,
          SchoolMove,
          SchoolMoveLogEntry
        ].each do |model|
          model.where(school_id: source_ids).update_all(
            school_id: merged_loc.id
          )
        end

        patient_location_ids_to_keep =
          PatientLocation
            .where(location_id: source_ids)
            .group(:patient_id, :academic_year)
            .minimum(:id)
            .values
        PatientLocation
          .where(location_id: source_ids)
          .where.not(id: patient_location_ids_to_keep)
          .delete_all
        PatientLocation.where(id: patient_location_ids_to_keep).update_all(
          location_id: merged_loc.id
        )
      end

    source_gl_tls.delete_all
    Location::ProgrammeYearGroup
      .joins(:location_year_group)
      .where(location_year_groups: { location_id: source_gl_location_ids })
      .delete_all
    Location::YearGroup.where(location_id: source_gl_location_ids).delete_all
    Location.where(id: source_gl_location_ids).delete_all
  end

  def refresh_materialized_views
    ReportingAPI::Total.refresh!(concurrently: false)
    ReportingAPI::PatientProgrammeStatus.refresh!(concurrently: false)
  rescue StandardError => e
    Rails.logger.warn "TeamMerge: could not refresh materialized views: #{e.message}"
  end

  def append_migration_counts
    SIMPLE_MODELS.each do |model|
      count = model.where(team_id: source_team_ids).count
      if count.positive?
        @dry_run_report << "#{model.table_name}: #{count} row(s) to migrate"
      end
    end

    {
      "archive_reasons" => ArchiveReason.where(team_id: source_team_ids).count,
      "important_notices" =>
        ImportantNotice.where(team_id: source_team_ids).count,
      "subteams" => Subteam.where(team_id: source_team_ids).count,
      "batches" => Batch.where(team_id: source_team_ids).count,
      "patients" =>
        PatientTeam
          .where(team_id: source_team_ids)
          .select(:patient_id)
          .distinct
          .count,
      "team_locations" => TeamLocation.where(team_id: source_team_ids).count,
      "teams_users" =>
        User.joins(:teams).where(teams: { id: source_team_ids }).distinct.count
    }.each do |table, count|
      if count.positive?
        @dry_run_report << "#{table}: #{count} row(s) to migrate"
      end
    end
  end

  def append_archive_reason_merges
    all_ids =
      ArchiveReason.where(team_id: source_team_ids).distinct.pluck(:patient_id)
    active_ids = active_in_some_source_team_ids.to_set
    partial = all_ids.select { |pid| active_ids.include?(pid) }
    fully = all_ids - partial

    if partial.any?
      @dry_run_report << "#{partial.size} patient(s) will be unarchived " \
        "(active in at least one source team)"
    end

    fully.each do |patient_id|
      reasons = ArchiveReason.where(team_id: source_team_ids, patient_id:).to_a
      next unless reasons.size > 1
      details =
        reasons.map do |archive_reason|
          detail =
            archive_reason.other? ? " (#{archive_reason.other_details})" : ""
          "#{source_teams_by_id[archive_reason.team_id].name}: #{archive_reason.type.humanize}#{detail}"
        end

      @dry_run_report << "Patient #{patient_id}: merging details → #{details.join(", ")}"
    end
  end

  def append_batch_skips
    Batch
      .where(team_id: source_team_ids)
      .group(:number, :expiry, :vaccine_id)
      .having(Arel.sql("COUNT(DISTINCT team_id) > 1"))
      .pluck(:number, :expiry, :vaccine_id)
      .each do |number, expiry, vaccine_id|
        @dry_run_report << "Batch #{number}/vaccine #{vaccine_id}/expiry #{expiry}: " \
          "duplicate across teams, will be skipped"
      end
  end
end
