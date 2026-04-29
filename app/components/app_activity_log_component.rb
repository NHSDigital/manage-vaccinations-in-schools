# frozen_string_literal: true

class AppActivityLogComponent < ViewComponent::Base
  erb_template <<-ERB
    <div class="app-timeline">
      <% all_events.each do |event| %>
        <%= render AppTimelineItemComponent.new(is_past: true, heading_level: 4) do |item| %>
          <% item.with_heading do %>
            <%= event[:invalidated] ? tag.s(event[:title]) : event[:title] %>
          <% end %>

          <% item.with_description do %>
            <% if (programmes = event[:programmes]) %>
              <%= render AppProgrammeTagsComponent.new(programmes) %>
            <% end %>

            <% if event[:invalidated] %><s><% end %>

            <% if (subtitle = event[:subtitle]).present? %>
              <%= subtitle %>
            <% else %>
              <% if (by = event[:by]) %>
                <%= by.respond_to?(:full_name) ? by.full_name : by %>
                &middot;
              <% end %>
              <%= event[:at].to_fs(:long) %>
            <% end %>

            <% if event[:invalidated] %></s><% end %>
          <% end %>

          <% if (body = event[:body]).present? %>
            <blockquote><p>
              <%= event[:invalidated] ? tag.s(body) : body %>
            </p></blockquote>
          <% end %>

          <% if (changes = event[:changes]).present? %>
            <%= render AppDetailsComponent.new(open: true) do |details| %>
              <% details.with_summary { pluralize(changes.size, "field") + " updated" } %>
              <%= changes_summary_list(changes) %>
            <% end %>
          <% end %>
        <% end %>
      <% end %>
    </div>
  ERB

  def initialize(team:, patient:, programme_type: nil, session: nil)
    @patient = patient
    @team = team
    @programme_type = programme_type
    @session = session
  end

  attr_reader :patient

  def all_events
    [
      archive_events,
      attendance_events,
      consent_events,
      expiration_events,
      gillick_assessment_events,
      note_events,
      notify_events,
      patient_change_events,
      patient_merge_events,
      patient_specific_direction_events,
      pre_screening_events,
      session_events,
      triage_events,
      vaccination_events
    ].flatten.sort_by { it[:at] }.reverse
  end

  def archive_events
    archive_reasons.flat_map do |archive_reason|
      {
        title: "Record archived: #{archive_reason.human_enum_name(:type)}",
        body: archive_reason.other_details,
        at: archive_reason.created_at,
        by: archive_reason.created_by
      }
    end
  end

  def consent_events
    consents.flat_map do |consent|
      events = []

      original_response =
        if consent.withdrawn?
          "given"
        elsif consent.follow_up_requested? || consent.follow_up_resolved?
          "follow_up_requested"
        else
          consent.response
        end
      human_response = Consent.human_enum_name(:response, original_response)

      title =
        if original_response == "not_provided"
          "Consent not provided"
        else
          human_response
        end

      events << if (consent_form = consent.consent_form)
        {
          title:,
          at: consent_form.recorded_at,
          by: consent_form.parent_relationship.label_with_parent,
          programmes: [consent.programme]
        }
      else
        {
          title:
            "#{title} by #{consent.name} (#{consent.who_responded.downcase_first})",
          at: consent.submitted_at,
          by: consent.recorded_by,
          programmes: [consent.programme]
        }
      end

      if consent.matched_manually?
        events << {
          title: "Consent response manually matched with child record",
          at: consent.created_at,
          by: consent.recorded_by,
          programmes: [consent.programme]
        }
      end

      if consent.invalidated? && !consent.follow_up_resolved?
        events << {
          title: "Consent from #{consent.name} invalidated",
          at: consent.invalidated_at,
          programmes: [consent.programme]
        }
      end

      if consent.withdrawn?
        events << {
          title: "Consent from #{consent.name} withdrawn",
          at: consent.withdrawn_at,
          programmes: [consent.programme]
        }
      end

      if consent.follow_up_resolved?
        events << {
          title:
            "Consent response from #{consent.name} (#{consent.who_responded.downcase_first}) " \
              "followed-up: refusal #{consent.follow_up_outcome}",
          at: consent.follow_up_resolved_at,
          programmes: [consent.programme]
        }
      end

      events
    end
  end

  def expiration_events
    return [] unless include_programme_specific_events?

    all_programmes = Programme.all.to_a

    AcademicYear.all.flat_map do |academic_year|
      next [] if academic_year >= AcademicYear.current

      not_vaccinated_programmes =
        all_programmes.reject do |programme|
          patient.programme_status(programme, academic_year:).vaccinated?
        end

      vaccinated_but_seasonal_programmes =
        all_programmes.select do |programme|
          patient.programme_status(programme, academic_year:).vaccinated? &&
            programme.seasonal?
        end

      expired_items =
        {
          vaccinated_but_seasonal: vaccinated_but_seasonal_programmes,
          not_vaccinated: not_vaccinated_programmes
        }.transform_values do |programmes|
          expired_items_for(academic_year:, programmes:)
        end

      expired_items.map do |category, expired_items_in_category|
        expired_item_names = []
        if expired_items_in_category[:consents].any?
          expired_item_names += ["consent", "health information"]
        end
        if expired_items_in_category[:triages].any?
          expired_item_names << "triage outcome"
        end
        if expired_items_in_category[:patient_specific_directions].any?
          expired_item_names << "PSD status"
        end

        next [] if expired_item_names.empty?

        title =
          "#{
            expired_item_names.to_sentence(
              words_connector: ", ",
              last_word_connector: " and "
            ).upcase_first
          } expired"

        body =
          case category
          when :not_vaccinated
            "#{patient.full_name} was not vaccinated."
          when :vaccinated_but_seasonal
            "#{patient.full_name} was vaccinated."
          end

        programmes = expired_items_in_category.values.flatten.uniq

        {
          title:,
          body:,
          at:
            academic_year.to_academic_year_date_range.end.end_of_day - 1.second,
          programmes:
        }
      end
    end
  end

  def gillick_assessment_events
    gillick_assessments.each_with_index.map do |gillick_assessment, index|
      action = index.zero? ? "Completed" : "Updated"
      outcome =
        (
          if gillick_assessment.gillick_competent?
            "Gillick competent"
          else
            "not Gillick competent"
          end
        )

      {
        title: "#{action} Gillick assessment as #{outcome}",
        body: gillick_assessment.notes,
        at: gillick_assessment.created_at,
        by: gillick_assessment.performed_by,
        programmes: [gillick_assessment.programme]
      }
    end
  end

  def note_events
    notes.map do |note|
      {
        title: "Note",
        body: note.body,
        at: note.created_at,
        by: note.created_by,
        programmes: note.programmes
      }
    end
  end

  def notify_events
    notify_log_entries.map do |notify_log_entry|
      {
        title: "#{notify_log_entry.title} sent",
        body: patient.restricted? ? "" : notify_log_entry.recipient,
        at: notify_log_entry.created_at,
        by: notify_log_entry.sent_by,
        programmes: notify_log_entry.programmes
      }
    end
  end

  def patient_change_events
    patient_change_log_entries.map do |entry|
      title =
        case entry.source
        when "manual_edit"
          "Record updated manually"
        when "cohort_import"
          "Record updated after new details were imported in a cohort upload"
        when "class_import"
          "Record updated after new details were imported in a class upload"
        else
          raise "Unknown change source: #{entry.source}"
        end
      {
        title:,
        at: entry.created_at,
        by: entry.user,
        changes: entry.recorded_changes
      }
    end
  end

  def patient_merge_events
    patient_merge_log_entries.map do |patient_merge_log_entry|
      {
        title: "Child record merged",
        body:
          "The record for #{patient_merge_log_entry.merged_patient_name} (date of birth " \
            "#{patient_merge_log_entry.merged_patient_dob.to_fs(:long)}) was merged with the record for " \
            "#{patient.full_name} (date of birth #{patient.date_of_birth.to_fs(:long)}) because they have the same " \
            "NHS number (#{patient_merge_log_entry.merged_patient_nhs_number}).",
        at: patient_merge_log_entry.created_at,
        by: patient_merge_log_entry.user
      }
    end
  end

  def patient_specific_direction_events
    patient_specific_directions.flat_map do |patient_specific_direction|
      events = []

      events << {
        title: "PSD added",
        at: patient_specific_direction.created_at,
        by: patient_specific_direction.created_by,
        programmes: [patient_specific_direction.programme]
      }

      if patient_specific_direction.invalidated?
        events << {
          title: "PSD invalidated",
          at: patient_specific_direction.invalidated_at,
          programmes: [patient_specific_direction.programme]
        }
      end

      events
    end
  end

  def pre_screening_events
    pre_screenings.map do |pre_screening|
      {
        title: "Completed pre-screening checks",
        body: pre_screening.notes,
        at: pre_screening.created_at,
        by: pre_screening.performed_by,
        programmes: [pre_screening.programme]
      }
    end
  end

  def session_events
    patient_locations.filter_map do |patient_location|
      location = patient_location.location
      next if location.generic_school?

      {
        title: "Added to the session at #{location.name}",
        at: patient_location.created_at
      }
    end
  end

  def triage_events
    triages.map do |triage|
      title = "Triaged decision: #{triage.human_enum_name(:status)}"

      if triage.vaccine_method.present? &&
           triage.programme.has_multiple_vaccine_methods?
        title += " with #{triage.human_enum_name(:vaccine_method)}"
      end

      {
        title:,
        body: triage.notes,
        at: triage.created_at,
        by: triage.performed_by,
        programmes: [triage.programme]
      }
    end
  end

  def vaccination_events
    events =
      vaccination_records.flat_map do |vaccination_record|
        if vaccination_record.sourced_from_nhs_immunisations_api? &&
             vaccination_record.discarded?
          next
        end

        title =
          if vaccination_record.administered?
            if (vaccine = vaccination_record.vaccine)
              "Vaccinated with #{vaccine.brand}"
            elsif vaccination_record.sourced_from_manual_report?
              "Vaccination record added manually"
            elsif vaccination_record.sourced_from_historical_upload?
              "Vaccination record uploaded"
            else
              "Vaccinated"
            end
          else
            "Vaccination not given: #{vaccination_record.human_enum_name(:outcome)}"
          end

        subtitle =
          if historical_vaccination_event?(vaccination_record)
            "Record added to Mavis #{vaccination_record.created_at.to_fs(:long)} · " \
              "Vaccination given #{vaccination_record.performed_at.to_date.to_fs(:long)}"
          end

        at =
          if historical_vaccination_event?(vaccination_record)
            vaccination_record.created_at
          else
            vaccination_record.performed_at
          end

        kept = {
          title:,
          body: vaccination_record.notes,
          at:,
          by: vaccination_record.performed_by,
          programmes: [vaccination_record.programme],
          subtitle:
        }

        discarded =
          if vaccination_record.discarded?
            {
              title: "Vaccination record archived",
              at: vaccination_record.discarded_at,
              programmes: [vaccination_record.programme]
            }
          end

        [kept, discarded].compact
      end

    events.compact
  end

  def historical_vaccination_event?(vaccination_record)
    vaccination_record.sourced_from_historical_upload? ||
      vaccination_record.sourced_from_manual_report?
  end

  def attendance_events
    attendance_records.map do |attendance_record|
      title =
        (
          if attendance_record.attending?
            "Attended session"
          else
            "Absent from session"
          end
        )

      title += " at #{attendance_record.location.name}"

      { title:, at: attendance_record.created_at }
    end
  end

  private

  delegate :format_nhs_number, :govuk_summary_list, to: :helpers

  def include_programme_specific_events?
    @programme_type.present? || @session.present?
  end

  def archive_reasons
    return [] if include_programme_specific_events?

    @archive_reasons ||=
      @patient.archive_reasons.where(team: @team).includes(:created_by)
  end

  def patient_change_log_entries
    return [] if include_programme_specific_events?

    @patient_change_log_entries ||=
      @patient.patient_change_log_entries.includes(:user)
  end

  def patient_merge_log_entries
    return [] if include_programme_specific_events?

    @patient_merge_log_entries ||=
      @patient.patient_merge_log_entries.includes(:user)
  end

  def attendance_records
    return [] unless include_programme_specific_events?

    @attendance_records ||=
      patient
        .attendance_records
        .includes(:location)
        .then do |scope|
          @session ? scope.where(location: @session.location) : scope
        end
  end

  def consents
    return [] unless include_programme_specific_events?

    @consents ||=
      @patient
        .consents
        .includes(
          :consent_form,
          :parent,
          :recorded_by,
          patient: :parent_relationships
        )
        .then do |scope|
          if @programme_type
            scope.where(programme_type: @programme_type)
          elsif @session
            scope.for_session(@session)
          else
            scope
          end
        end
  end

  def gillick_assessments
    return [] unless include_programme_specific_events?

    @gillick_assessments ||=
      @patient
        .gillick_assessments
        .includes(:performed_by)
        .order(:created_at)
        .then do |scope|
          if @programme_type
            scope.where(programme_type: @programme_type)
          elsif @session
            scope.for_session(@session)
          else
            scope
          end
        end
  end

  def notes
    return [] unless include_programme_specific_events?

    @notes ||=
      @patient
        .notes
        .includes(:created_by, :patient, :session)
        .then { |scope| @session ? scope.where(session: @session) : scope }
  end

  def notify_log_entries
    return [] unless include_programme_specific_events?

    @notify_log_entries ||=
      @patient
        .notify_log_entries
        .includes(:sent_by)
        .preload(:notify_log_entry_programmes)
        .then do |scope|
          if @programme_type
            scope.for_programme_type(@programme_type)
          elsif @session
            scope.for_session(@session)
          else
            scope
          end
        end
  end

  def patient_locations
    return [] unless include_programme_specific_events?

    @patient_locations ||=
      @patient
        .patient_locations
        .includes(:location)
        .then do |scope|
          @session ? scope.where(location: @session.location) : scope
        end
  end

  def patient_specific_directions
    return [] unless include_programme_specific_events?

    @patient_specific_directions ||=
      @patient
        .patient_specific_directions
        .includes(:created_by)
        .then do |scope|
          if @programme_type
            scope.where(programme_type: @programme_type)
          elsif @session
            scope.for_session(@session)
          else
            scope
          end
        end
  end

  def pre_screenings
    return [] unless include_programme_specific_events?

    @pre_screenings ||=
      @patient
        .pre_screenings
        .includes(:performed_by)
        .then do |scope|
          if @programme_type
            scope.where(programme_type: @programme_type)
          elsif @session
            scope.for_session(@session)
          else
            scope
          end
        end
  end

  def triages
    return [] unless include_programme_specific_events?

    @triages ||=
      @patient
        .triages
        .includes(:performed_by)
        .then do |scope|
          if @programme_type
            scope.where(programme_type: @programme_type)
          elsif @session
            scope.for_session(@session)
          else
            scope
          end
        end
  end

  def vaccination_records
    return [] unless include_programme_specific_events?

    @vaccination_records ||=
      @patient
        .vaccination_records
        .with_discarded
        .includes(:performed_by_user, :vaccine)
        .then do |scope|
          @programme_type ? scope.where(programme_type: @programme_type) : scope
        end
  end

  def changes_summary_list(changes)
    rows =
      PatientChangeLogEntry::TRACKED_ATTRIBUTES.filter_map do |attr|
        next unless changes.key?(attr)

        old_val, new_val = changes[attr]
        {
          key: {
            text: PatientChangeLogEntry.label_for(attr)
          },
          value: {
            text: change_value_html(attr, old_val, new_val)
          }
        }
      end
    govuk_summary_list(rows:)
  end

  def change_value_html(attr, old_val, new_val)
    arrow =
      tag.svg(
        safe_join(
          [
            tag.title("changed to"),
            tag.path(
              d:
                "m14.7 6.3 5 5c.2.2.3.4.3.7 0 .3-.1.5-.3.7l-5 5" \
                  "a1 1 0 0 1-1.4-1.4l3.3-3.3H5a1 1 0 0 1 0-2" \
                  "h11.6l-3.3-3.3a1 1 0 1 1 1.4-1.4Z"
            )
          ]
        ),
        class: "nhsuk-icon nhsuk-icon--arrow-right",
        style: "vertical-align: middle",
        xmlns: "http://www.w3.org/2000/svg",
        viewBox: "0 0 24 24",
        width: "16",
        height: "16",
        focusable: "false",
        role: "img",
        "aria-label": "changed to"
      )

    safe_join(
      [
        format_change_value(attr, old_val),
        " ",
        arrow,
        " ",
        tag.mark(format_change_value(attr, new_val), class: "app-highlight")
      ]
    )
  end

  def format_change_value(attr, value)
    return "Not provided" if value.nil? || value.to_s.empty?

    case attr
    when "date_of_birth"
      Date.parse(value.to_s).to_fs(:long)
    when "gender_code"
      Patient.human_enum_name(:gender_code, value)
    when "nhs_number"
      format_nhs_number(value.to_s)
    else
      value.to_s
    end
  end

  def expired_items_for(academic_year:, programmes:)
    {
      consents:,
      triages:,
      patient_specific_directions:
    }.transform_values do |items|
      items
        .select { it.academic_year == academic_year }
        .map(&:programme)
        .select { programmes.include?(it) }
    end
  end
end
