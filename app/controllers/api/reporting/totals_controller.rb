# frozen_string_literal: true

class API::Reporting::TotalsController < API::Reporting::BaseController
  FILTERS = {
    academic_year: :academic_year,
    programme: :programme_type,
    gender: :patient_gender,
    year_group: :patient_year_group,
    school_local_authority: :patient_school_local_authority_code,
    local_authority: :patient_local_authority_code
  }.freeze

  GROUPS = {
    local_authority: :patient_local_authority_official_name,
    year_group: :patient_year_group,
    gender: :patient_gender,
    school: %i[patient_school_urn patient_school_name]
  }.freeze

  GROUP_HEADERS = {
    patient_local_authority_official_name: "Local Authority",
    patient_year_group: "Year Group",
    patient_gender: "Gender",
    patient_school_urn: "School URN",
    patient_school_name: "School Name"
  }.freeze

  METRIC_HEADERS = {
    cohort: "Cohort",
    no_consent: "No Consent",
    consent_no_response: "Consent No Response",
    consent_refused: "Consent Refused",
    consent_conflicts: "Consent Conflicts",
    consent_given: "Consent Given",
    not_vaccinated: "Not Vaccinated",
    vaccinated: "Vaccinated"
  }.freeze

  FLU_SPECIFIC_METRIC_HEADERS = {}.freeze

  before_action :set_default_filters, :set_filters, :set_scope

  def index
    respond_to do |format|
      format.csv { render_format_csv }
      format.any { render_format_json }
    end
  end

  private

  def set_default_filters
    params[:academic_year] ||= AcademicYear.current
  end

  def set_filters
    @filters = ReportingAPI::EventFilter.new(params:, filters: FILTERS)
  end

  def set_scope
    @totals_base_scope =
      ReportingAPI::Total.where(team_id: current_user.team_ids).where(
        @filters.to_where_clause
      )

    apply_workgroup_filter
    apply_year_group_filter

    @totals_scope = @totals_base_scope.not_archived
  end

  def csv_headers(groups)
    headers = {}

    groups.each { |group_attr| headers[GROUP_HEADERS[group_attr]] = group_attr }

    METRIC_HEADERS.each { |attr, header| headers[header] = attr }

    if params[:programme] == "flu"
      FLU_SPECIFIC_METRIC_HEADERS.each { |attr, header| headers[header] = attr }
    end

    headers
  end

  def parse_groups
    params[:group]
      .to_s
      .split(",")
      .map { GROUPS[it.strip.to_sym] }
      .compact
      .flatten
      .uniq
  end

  def render_format_csv
    groups = parse_groups

    scope = @totals_scope
    scope = scope.group(groups).select(groups) if groups.any?
    records = scope.with_aggregate_metrics

    render_csv records:, header_mappings: csv_headers(groups), prefix: "totals"
  end

  def render_format_json
    groups = parse_groups

    groups.any? ? render_grouped_json(groups) : render_totals_json
  end

  def render_grouped_json(groups)
    records = @totals_scope.group(groups).select(groups).with_aggregate_metrics
    render json: records.map { grouped_record_json(it, groups) }
  end

  def grouped_record_json(record, groups)
    groups
      .to_h { [it.to_s.delete_prefix("patient_").to_sym, record[it]] }
      .merge(
        cohort: record.cohort,
        vaccinated: record.vaccinated,
        not_vaccinated: record.not_vaccinated,
        consent_given: record.consent_given,
        no_consent: record.no_consent,
        consent_no_response: record.consent_no_response,
        consent_refused: record.consent_refused,
        consent_conflicts: record.consent_conflicts
      )
  end

  def render_totals_json
    metrics = @totals_scope.with_aggregate_metrics.take

    render json: {
             cohort: metrics.cohort,
             vaccinated: metrics.vaccinated,
             not_vaccinated: metrics.cohort - metrics.vaccinated,
             consent_given: metrics.consent_given,
             no_consent: metrics.no_consent,
             consent_no_response: metrics.consent_no_response,
             consent_refused: metrics.consent_refused,
             consent_conflicts: metrics.consent_conflicts,
             vaccinations_given: team_vaccinations_given_count,
             monthly_vaccinations_given: team_monthly_vaccinations_given
           }
  end

  def apply_workgroup_filter
    workgroup = params[:workgroup].presence || cis2_info.team_workgroup
    return unless workgroup

    @team = current_user.teams.find_by(workgroup:)
    return unless @team

    @totals_base_scope = @totals_base_scope.where(team_id: @team.id)
  end

  def apply_year_group_filter
    return if params[:programme].blank?

    lpyg_table = Location::ProgrammeYearGroup.arel_table
    lyg_table = Location::YearGroup.arel_table

    totals_table = ReportingAPI::Total.arel_table
    totals_subquery =
      lpyg_table
        .project(Arel.star)
        .join(lyg_table)
        .on(lpyg_table[:location_year_group_id].eq(lyg_table[:id]))
        .where(lyg_table[:location_id].eq(totals_table[:session_location_id]))
        .where(lyg_table[:value].eq(totals_table[:patient_year_group]))
        .where(lyg_table[:academic_year].eq(totals_table[:academic_year]))
        .where(lpyg_table[:programme_type].eq(params[:programme]))
    @totals_base_scope =
      @totals_base_scope.where(Arel::Nodes::Exists.new(totals_subquery))
  end

  def team_vaccination_records_scope
    VaccinationRecord
      .where(discarded_at: nil, outcome: :administered)
      .joins(session: :team_location)
      .where(
        team_locations: {
          team_id: @team&.id || current_user.team_ids,
          academic_year: params[:academic_year]
        }
      )
      .where(
        "vaccination_records.programme_type != 'td_ipv'" \
          " OR vaccination_records.dose_sequence = 5" \
          " OR vaccination_records.dose_sequence IS NULL"
      )
      .then do |scope|
        if params[:programme].present?
          scope.where(vaccination_records: { programme_type: params[:programme] })
        else
          scope
        end
      end
  end

  def team_vaccinations_given_count
    team_vaccination_records_scope.count
  end

  def team_monthly_vaccinations_given
    counts =
      team_vaccination_records_scope
        .group(
          Arel.sql(
            "EXTRACT(YEAR FROM vaccination_records.performed_at_date)::integer"
          ),
          Arel.sql(
            "EXTRACT(MONTH FROM vaccination_records.performed_at_date)::integer"
          )
        )
        .count
        .map do |(year, month), count|
          { year:, month: Date::MONTHNAMES[month], count: }
        end
    counts.sort_by! { [it[:year], Date::MONTHNAMES.index(it[:month])] }
  end
end
