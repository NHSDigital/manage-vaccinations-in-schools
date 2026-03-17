# frozen_string_literal: true

class AppPatientSearchResultCardComponent < ViewComponent::Base
  def initialize(
    patient,
    link_to:,
    current_team:,
    programmes: [],
    academic_year: nil,
    show_clinic_invitations: false,
    show_nhs_number: false,
    show_parents: false,
    show_postcode: false,
    show_programme_status: true,
    show_school: false,
    show_vaccinated_programme_status_only: false,
    show_year_group: false,
    heading_level: 4
  )
    @patient = patient
    @link_to = link_to
    @current_team = current_team

    @programmes = programmes
    @academic_year = academic_year || AcademicYear.pending
    @heading_level = heading_level

    @show_clinic_invitations = show_clinic_invitations
    @show_nhs_number = show_nhs_number
    @show_parents = show_parents
    @show_postcode = show_postcode
    @show_programme_status = show_programme_status
    @show_school = show_school
    @show_vaccinated_programme_status_only =
      show_vaccinated_programme_status_only
    @show_year_group = show_year_group
  end

  def call
    render AppCardComponent.new(link_to:, compact: true) do |card|
      card.with_heading(level: @heading_level) do
        patient.full_name_with_known_as
      end
      govuk_summary_list(rows:)
    end
  end

  private

  attr_reader :patient,
              :link_to,
              :current_team,
              :programmes,
              :academic_year,
              :triage_status,
              :show_clinic_invitations,
              :show_nhs_number,
              :show_parents,
              :show_postcode,
              :show_programme_status,
              :show_school,
              :show_vaccinated_programme_status_only,
              :show_year_group

  delegate :govuk_summary_list,
           :patient_date_of_birth,
           :patient_nhs_number,
           :patient_parents,
           :patient_school,
           :patient_year_group,
           to: :helpers

  def rows
    [
      nhs_number_row,
      date_of_birth_row,
      year_group_row,
      postcode_row,
      school_row,
      parents_row,
      clinic_invitations_row,
      programme_status_row
    ].compact
  end

  def nhs_number_row
    return unless show_nhs_number

    {
      key: {
        text: "NHS number"
      },
      value: {
        text: patient_nhs_number(patient)
      }
    }
  end

  def date_of_birth_row
    {
      key: {
        text: "Date of birth"
      },
      value: {
        text: patient_date_of_birth(patient)
      }
    }
  end

  def year_group_row
    return unless show_year_group

    {
      key: {
        text: "Year group"
      },
      value: {
        text: patient_year_group(patient, academic_year:)
      }
    }
  end

  def clinic_invitations_row
    return unless show_clinic_invitations && academic_year

    clinic_notifications =
      patient.clinic_notifications.select do
        it.team_id == current_team.id && it.academic_year == academic_year
      end

    programmes = clinic_notifications.flat_map(&:programmes).uniq.sort

    return if programmes.empty?

    {
      key: {
        text: "Clinic invitations"
      },
      value: {
        text: render(AppProgrammeTagsComponent.new(programmes))
      }
    }
  end

  def postcode_row
    return unless show_postcode && !patient.restricted?

    { key: { text: "Postcode" }, value: { text: patient.address_postcode } }
  end

  def school_row
    return unless show_school

    { key: { text: "School" }, value: { text: patient_school(patient) } }
  end

  def parents_row
    return unless show_parents && patient.parent_relationships.any?

    {
      key: {
        text: "Parents or guardians"
      },
      value: {
        text: patient_parents(patient)
      }
    }
  end

  def programme_status_row
    return unless show_programme_status && academic_year

    status_by_programme =
      programmes.each_with_object({}) do |programme, hash|
        resolved_status =
          PatientProgrammeStatusResolver.call(
            patient,
            programme_type: programme.type,
            academic_year:,
            only_if_vaccinated: show_vaccinated_programme_status_only
          )

        next unless resolved_status

        hash[resolved_status.fetch(:prefix)] = resolved_status
      end

    return if status_by_programme.empty?

    {
      key: {
        text: "Programme status"
      },
      value: {
        text: render(AppAttachedTagsComponent.new(status_by_programme))
      }
    }
  end
end
