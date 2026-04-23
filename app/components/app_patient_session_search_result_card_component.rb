# frozen_string_literal: true

class AppPatientSessionSearchResultCardComponent < ViewComponent::Base
  def initialize(
    patient:,
    session:,
    programmes: [],
    return_to: nil,
    show_notes: false,
    show_patient_specific_direction_status: false,
    show_programme_status: false,
    show_registration_status: false,
    show_vaccine_type: false,
    heading_level: 4
  )
    @patient = patient
    @session = session

    @programmes =
      if programmes.present?
        session.programmes_for(patient:).select { it.in?(programmes) }
      else
        session.programmes_for(patient:)
      end

    @return_to = return_to

    @show_notes = show_notes
    @show_patient_specific_direction_status =
      show_patient_specific_direction_status
    @show_programme_status = show_programme_status
    @show_registration_status = show_registration_status
    @show_vaccine_type = show_vaccine_type
    @heading_level = heading_level
  end

  def call
    render AppCardComponent.new(link_to: card_link, compact: true) do |card|
      card.with_heading(level: @heading_level, size: "s") { heading }
      safe_join([summary_list, registration_buttons].compact)
    end
  end

  private

  attr_reader :patient,
              :session,
              :programmes,
              :return_to,
              :show_notes,
              :show_patient_specific_direction_status,
              :show_programme_status,
              :show_registration_status,
              :show_vaccine_type

  delegate :govuk_button_to,
           :govuk_summary_list,
           :patient_date_of_birth,
           :patient_year_group,
           :policy,
           to: :helpers

  delegate :academic_year, :team, to: :session

  def programme_types = programmes.map(&:type)

  def card_link = show_registration_status ? nil : patient_path

  def heading
    if card_link.nil?
      link_to(patient.full_name_with_known_as, patient_path)
    else
      patient.full_name_with_known_as
    end
  end

  def patient_path
    session_patient_programme_path(
      session,
      patient,
      programmes.first,
      return_to:
    )
  end

  def summary_list = govuk_summary_list(rows:)

  def rows
    [
      date_of_birth_row,
      year_group_row,
      vaccine_type_row,
      registration_status_row,
      programme_status_row,
      patient_specific_direction_status_row,
      notes_row
    ].compact
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
    {
      key: {
        text: "Year group"
      },
      value: {
        text: patient_year_group(patient, academic_year:)
      }
    }
  end

  def vaccine_type_row
    return unless show_vaccine_type && (labels = vaccine_type_labels).present?

    text =
      if labels.size == 1
        labels.first
      else
        tag.ul(class: "nhsuk-list nhsuk-list--bullet") do
          safe_join(labels.map { tag.li(it) })
        end
      end

    { key: { text: "Vaccine type" }, value: { text: } }
  end

  def vaccine_type_labels
    programmes_to_check =
      programmes.select do
        it.has_multiple_vaccine_methods? || it.vaccine_may_contain_gelatine?
      end

    return if programmes_to_check.empty?

    programmes_with_variants =
      programmes_to_check.map do |programme|
        disease_types =
          patient.programme_status(programme, academic_year:).disease_types

        programme.variant_for(disease_types:)
      end

    programmes_with_variants.filter_map do |programme|
      if patient.consent_given_and_safe_to_vaccinate?(
           programme:,
           academic_year:
         )
        vaccine_criteria = patient.vaccine_criteria(programme:, academic_year:)

        render AppVaccineCriteriaLabelComponent.new(
                 vaccine_criteria,
                 programme:,
                 context: :vaccine_type
               )
      end
    end
  end

  def registration_status_row
    return unless show_registration_status

    {
      key: {
        text: I18n.t("status.label.registration")
      },
      value: {
        text:
          render(
            AppStatusTagComponent.new(
              patient.registration_status(session:)&.status || "unknown",
              context: :registration
            )
          )
      }
    }
  end

  def programme_status_row
    return unless show_programme_status

    status_by_programme =
      programmes.each_with_object({}) do |programme, hash|
        resolved_status =
          PatientProgrammeStatusResolver.call(
            patient,
            programme_type: programme.type,
            academic_year:,
            context_location_id: session.location_id
          )

        hash[resolved_status.fetch(:prefix)] = resolved_status
      end

    {
      key: {
        text: I18n.t("status.label.programme")
      },
      value: {
        text: render(AppAttachedTagsComponent.new(status_by_programme))
      }
    }
  end

  def patient_specific_direction_status_row
    return unless show_patient_specific_direction_status

    {
      key: {
        text: I18n.t("status.label.patient_specific_direction")
      },
      value: {
        text:
          render(
            AppStatusTagComponent.new(
              has_patient_specific_direction? ? :added : :not_added,
              context: :patient_specific_direction
            )
          )
      }
    }
  end

  def has_patient_specific_direction?
    patient.patient_specific_directions.any? do
      it.programme_type.in?(programme_types) &&
        it.academic_year == academic_year && !it.invalidated?
    end
  end

  def notes_row
    return unless show_notes && latest_note

    truncated_body = tag.p(latest_note.body.truncate_words(80, omission: "…"))

    continue_reading =
      if truncated_body.include?("…")
        tag.p(class: "nhsuk-u-margin-bottom-0") do
          link_to(session_patient_activity_path(session, patient)) do
            tag.span("Continue reading") +
              tag.span(
                "note for #{patient.full_name}",
                class: "nhsuk-u-visually-hidden"
              )
          end
        end
      end

    blockquote =
      tag.blockquote { safe_join([truncated_body, continue_reading]) }

    subtitle =
      tag.p(
        "#{latest_note.created_by.full_name} &middot; #{latest_note.created_at.to_fs(:long)}".html_safe,
        class: "nhsuk-body-s nhsuk-u-margin-0 nhsuk-u-secondary-text-colour"
      )

    {
      key: {
        text: "Notes"
      },
      value: {
        text: safe_join([blockquote, subtitle])
      }
    }
  end

  def latest_note
    @latest_note ||=
      patient
        .notes
        .sort_by(&:created_at)
        .reverse
        .find { it.session_id == session.id }
  end

  def registration_buttons
    return unless show_registration_status && can_register_attendance?

    tag.div(class: "nhsuk-button-group") do
      safe_join(
        [
          govuk_button_to(
            "Attending",
            register_session_patients_path(session, patient, "present"),
            secondary: true,
            class: "nhsuk-button--small"
          ),
          govuk_button_to(
            "Absent",
            register_session_patients_path(session, patient, "absent"),
            class: "app-button--secondary-warning nhsuk-button--small"
          )
        ]
      )
    end
  end

  def can_register_attendance?
    attendance_record =
      AttendanceRecord.new(
        patient:,
        location: session.location,
        date: Date.current
      )

    attendance_record.session = session

    policy(attendance_record).new?
  end
end
