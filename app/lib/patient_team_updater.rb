# frozen_string_literal: true

##
# This class is used to update the patient-team associations for any
# particular set of patients or teams. Patient-team associations are a cache
# of which teams have access to view which patients, and the logic depends on
# a number of associated tables. For example, a patient is considered part of
# a team if they have an archive reason, or vaccination record for that team.
#
# A `patient_scope` and `team_scope` can be passed in to limit the scope of
# which patients and teams get updated. Without these arguments the default
# is to update all the patients and teams.
#
# If a patient or team scope is provided which has just a where clause on the
# ID (for example `Patient.where(id: 10)`), the class will attempt an
# optimisation which avoids a join and instead filters directly on the ID in
# the relation.
#
# The updater works by executing two queries. The first query is a bulk update
# using `INSERT ... ON CONFLICT DO UPDATE` to update all the patient-team
# associations by setting the array of sources for each association. The
# sources array contains all the possible reasons why a patient might be
# associated with a team (for example `archive_reason` or
# `vaccination_record_organisation`). The second query deletes any rows from
# the table where the sources array is empty (meaning the patient should not
# belong to the team.).
class PatientTeamUpdater < PatientScopedUpdater
  def initialize(patient_scope: nil, patient: nil, team_scope: nil, team: nil)
    super(patient_scope:, patient:)

    @team_scope = (team ? Team.where(id: team.id) : team_scope)
  end

  def call
    upsert_patient_teams!
    delete_patient_teams_without_sources!
  end

  def self.call(...) = new(...).call

  private_class_method :new

  private

  attr_reader :patient_scope, :team_scope

  def upsert_patient_teams!
    PatientTeam.connection.execute(<<~SQL)
      INSERT INTO patient_teams (patient_id, team_id, sources)
      #{grouped_relations_sql}
      ON CONFLICT (patient_id, team_id)
      DO UPDATE SET sources = EXCLUDED.sources
      WHERE patient_teams.sources IS DISTINCT FROM EXCLUDED.sources
    SQL
  end

  def delete_patient_teams_without_sources!
    PatientTeam.missing_sources.delete_all
  end

  def grouped_relations_sql
    union_all_sql =
      relations.map(&:to_sql).join(" UNION ALL ").then { Arel.sql(it) }

    PatientTeam
      .from("(#{union_all_sql})")
      .group(:patient_id, :team_id)
      .select(
        :patient_id,
        :team_id,
        "array_remove(array_agg(DISTINCT source ORDER BY source), NULL)"
      )
      .to_sql
  end

  # These make up the various tables that contribute towards a patient
  #  belonging to a particular team.

  def relations
    @relations ||= [
      archive_reason_relation,
      null_relation,
      patient_location_relation,
      school_move_school_relation,
      vaccination_record_import_relation,
      vaccination_record_session_relation
    ]
  end

  def archive_reason_relation
    source = PatientTeam.sources.fetch("archive_reason")

    scope = merge_team_scope(merge_patient_scope(ArchiveReason))

    scope.select(:patient_id, :team_id, Arel.sql("#{source} AS source"))
  end

  def null_relation
    # This relation represents all the existing patient teams that exist for
    #  this patient scope and team scope. It ensures that if any existing
    #  patient teams no longer exist in the other relations, the sources array
    #  will be empty and then can be upserted.

    source = "NULL::integer"

    scope = merge_team_scope(merge_patient_scope(PatientTeam))

    scope.select(:patient_id, :team_id, Arel.sql("#{source} AS source"))
  end

  def patient_location_relation
    source = PatientTeam.sources.fetch("patient_location")

    scope =
      merge_patient_scope(
        joins_team_locations_alias_on_patient_locations(PatientLocation)
      )

    if is_team_scope_id_only?
      scope =
        scope.where(team_locations_alias: { team_id: team_scope.select(:id) })
    elsif team_scope
      scope = joins_teams_on_team_locations_alias(scope).merge(team_scope)
    end

    scope.select(
      :patient_id,
      Arel.sql("team_locations_alias.team_id AS team_id"),
      Arel.sql("#{source} AS source")
    )
  end

  def school_move_school_relation
    source = PatientTeam.sources.fetch("school_move_school")

    scope =
      merge_patient_scope(
        joins_team_locations_alias_on_school_moves(SchoolMove)
      )

    if is_team_scope_id_only?
      scope =
        scope.where(team_locations_alias: { team_id: team_scope.select(:id) })
    elsif team_scope
      scope = joins_teams_on_team_locations_alias(scope).merge(team_scope)
    end

    scope.select(
      :patient_id,
      Arel.sql("team_locations_alias.team_id AS team_id"),
      Arel.sql("#{source} AS source")
    )
  end

  def vaccination_record_import_relation
    source = PatientTeam.sources.fetch("vaccination_record_import")

    scope = merge_patient_scope(VaccinationRecord.joins(:immunisation_imports))

    if is_team_scope_id_only?
      scope =
        scope.where(immunisation_imports: { team_id: team_scope.select(:id) })
    elsif team_scope
      scope = scope.joins(immunisation_imports: :team).merge(team_scope)
    end

    scope.select(
      :patient_id,
      Arel.sql("immunisation_imports.team_id AS team_id"),
      Arel.sql("#{source} AS source")
    )
  end

  def vaccination_record_session_relation
    source = PatientTeam.sources.fetch("vaccination_record_session")

    scope =
      merge_patient_scope(
        joins_team_locations_alias_on_vaccination_records(VaccinationRecord)
      )

    if is_team_scope_id_only?
      scope =
        scope.where(team_locations_alias: { team_id: team_scope.select(:id) })
    elsif team_scope
      scope = joins_teams_on_team_locations_alias(scope).merge(team_scope)
    end

    scope.select(
      :patient_id,
      Arel.sql("team_locations_alias.team_id AS team_id"),
      Arel.sql("#{source} AS source")
    )
  end

  # These are aliased joins that we need to perform in case the patient or
  #  team scopes already make reference to these tables.

  def joins_team_locations_alias_on_patient_locations(scope)
    scope.joins(<<-SQL).references(:team_locations_alias)
      INNER JOIN team_locations team_locations_alias
      ON team_locations_alias.location_id = patient_locations.school_id
      AND team_locations_alias.academic_year = patient_locations.academic_year
    SQL
  end

  def joins_team_locations_alias_on_school_moves(scope)
    scope.joins(<<-SQL).references(:team_locations_alias)
      INNER JOIN team_locations team_locations_alias
      ON team_locations_alias.location_id = school_moves.school_id
      AND team_locations_alias.academic_year = school_moves.academic_year
    SQL
  end

  def joins_team_locations_alias_on_vaccination_records(scope)
    scope.joins(<<-SQL).references(:sessions_alias, :team_locations_alias)
      INNER JOIN sessions sessions_alias
      ON sessions_alias.id = vaccination_records.session_id
      INNER JOIN team_locations team_locations_alias
      ON team_locations_alias.id = sessions_alias.team_location_id
    SQL
  end

  def joins_teams_on_team_locations_alias(scope)
    scope.joins("INNER JOIN teams ON teams.id = team_locations_alias.team_id")
  end

  # The following code is used to support an optimisation where we're updating
  #  a specific team by ID.

  def merge_team_scope(scope)
    if is_team_scope_id_only?
      scope.where(team_id: team_scope.select(:id))
    elsif team_scope
      scope.joins(:team).merge(team_scope)
    else
      scope
    end
  end

  def is_team_scope_id_only?
    @is_team_scope_id_only ||= is_id_only_scope?(team_scope)
  end
end
