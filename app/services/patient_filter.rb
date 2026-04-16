# frozen_string_literal: true

class PatientFilter
  attr_reader :academic_year,
              :session,
              :aged_out_of_programmes,
              :archived,
              :date_of_birth_day,
              :date_of_birth_month,
              :date_of_birth_year,
              :invited_to_clinic,
              :missing_nhs_number,
              :patient_specific_direction_status,
              :programme_status_group,
              :programme_statuses,
              :programme_types,
              :q,
              :registration_status,
              :team,
              :vaccine_criteria,
              :year_groups

  def initialize(
    team: nil,
    session: nil,
    academic_year: nil,
    aged_out_of_programmes: nil,
    archived: nil,
    date_of_birth_day: nil,
    date_of_birth_month: nil,
    date_of_birth_year: nil,
    invited_to_clinic: nil,
    missing_nhs_number: nil,
    patient_specific_direction_status: nil,
    programme_status_group: nil,
    programme_statuses: nil,
    programme_types: nil,
    q: nil,
    registration_status: nil,
    vaccine_criteria: nil,
    year_groups: nil
  )
    @team = team
    @session = session
    @academic_year = academic_year

    @aged_out_of_programmes = aged_out_of_programmes
    @archived = archived
    @invited_to_clinic = invited_to_clinic
    @missing_nhs_number = missing_nhs_number

    @date_of_birth_day = date_of_birth_day
    @date_of_birth_month = date_of_birth_month
    @date_of_birth_year = date_of_birth_year

    @patient_specific_direction_status = patient_specific_direction_status
    @programme_status_group = programme_status_group
    @programme_statuses = programme_statuses
    @programme_types = programme_types
    @q = q
    @registration_status = registration_status
    @vaccine_criteria = vaccine_criteria
    @year_groups = year_groups
  end

  def programmes
    @programmes ||=
      if programme_types.present?
        Programme.find_all(programme_types)
      else
        session&.programmes || team&.programmes || []
      end
  end

  def apply(scope)
    scope = filter_aged_out_of_programmes(scope)
    scope = filter_archived(scope)
    scope = filter_date_of_birth_year(scope)
    scope = filter_invited_to_clinic(scope)
    scope = filter_name(scope)
    scope = filter_nhs_number(scope)
    scope = filter_patient_specific_direction_status(scope)
    scope = filter_programme_statuses(scope)
    scope = filter_programmes(scope)
    scope = filter_registration_status(scope)
    scope = filter_vaccine_criteria(scope)
    scope = filter_year_groups(scope)

    scope.order_by_name
  end

  private

  def filter_aged_out_of_programmes(scope)
    return scope if team.has_national_reporting_access?

    if aged_out_of_programmes
      scope.not_appear_in_programmes(team.programmes, academic_year:)
    elsif session || archived
      # Archived patients won't appear in programmes, so we need to
      # skip this check if we're trying to view archived patients.
      scope
    else
      scope.appear_in_programmes(team.programmes, academic_year:)
    end
  end

  def filter_archived(scope)
    return scope if team.has_national_reporting_access?

    if archived
      scope.archived(team:)
    elsif session
      scope
    else
      scope.not_archived(team:)
    end
  end

  def filter_date_of_birth_year(scope)
    if date_of_birth_year.present?
      scope = scope.search_by_date_of_birth_year(date_of_birth_year)
    end

    if date_of_birth_month.present?
      scope = scope.search_by_date_of_birth_month(date_of_birth_month)
    end

    if date_of_birth_day.present?
      scope = scope.search_by_date_of_birth_day(date_of_birth_day)
    end

    scope
  end

  def filter_invited_to_clinic(scope)
    if invited_to_clinic
      scope.has_clinic_notification(team:, academic_year:, programmes:)
    else
      scope
    end
  end

  def filter_name(scope)
    q.present? ? scope.search_by_name_or_nhs_number(q) : scope
  end

  def filter_nhs_number(scope)
    missing_nhs_number.present? ? scope.search_by_nhs_number(nil) : scope
  end

  def filter_patient_specific_direction_status(scope)
    return scope if (status = patient_specific_direction_status&.to_sym).blank?

    case status
    when :added
      scope.with_patient_specific_direction(
        programme: programmes,
        academic_year:,
        team:
      )
    when :not_added
      scope.without_patient_specific_direction(
        programme: programmes,
        academic_year:,
        team:
      )
    else
      scope
    end
  end

  def filter_programme_statuses(scope)
    return scope if programme_status_group.blank?

    statuses =
      programme_statuses&.select { it.starts_with?(programme_status_group) }

    if statuses.blank?
      statuses =
        Patient::ProgrammeStatus.statuses.keys.select do
          it.starts_with?(programme_status_group)
        end
    end

    return scope if statuses.empty?

    or_scope =
      scope.has_programme_status(
        statuses.first,
        programme: programmes,
        academic_year:
      )

    statuses
      .drop(1)
      .each do |value|
        or_scope =
          or_scope.or(
            scope.has_programme_status(
              value,
              programme: programmes,
              academic_year:
            )
          )
      end

    or_scope
  end

  def filter_programmes(scope)
    if programme_types.present?
      if session
        scope.appear_in_programmes(programmes, session:)
      else
        scope.appear_in_programmes(programmes, academic_year:)
      end
    else
      scope
    end
  end

  def filter_registration_status(scope)
    if (status = registration_status&.to_sym).present?
      scope.has_registration_status(status, session:)
    else
      scope
    end
  end

  def filter_vaccine_criteria(scope)
    return scope if vaccine_criteria.blank?

    vaccine_criteria_instances =
      vaccine_criteria.map { |param| VaccineCriteria.from_param(param) }

    or_scope =
      scope.has_vaccine_criteria(
        programme: vaccine_criteria_instances.first.programme,
        academic_year:,
        vaccine_methods: vaccine_criteria_instances.first.vaccine_methods,
        without_gelatine: vaccine_criteria_instances.first.without_gelatine
      )

    vaccine_criteria_instances
      .drop(1)
      .each do |value|
        or_scope =
          or_scope.or(
            scope.has_vaccine_criteria(
              programme: value.programme,
              academic_year:,
              vaccine_methods: value.vaccine_methods,
              without_gelatine: value.without_gelatine
            )
          )
      end

    or_scope
  end

  def filter_year_groups(scope)
    if year_groups.present?
      scope.search_by_year_groups(year_groups, academic_year:)
    else
      scope
    end
  end
end
