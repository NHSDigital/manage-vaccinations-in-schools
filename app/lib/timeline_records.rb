# frozen_string_literal: true

class TimelineRecords
  DEFAULT_DETAILS_CONFIG = {
    changesets: %i[import_id import_type],
    class_imports: %i[],
    cohort_imports: %i[],
    consents: %i[programme_type response route],
    school_move_log_entries: %i[school_id user_id],
    school_moves: %i[school_id source],
    sessions: %i[location_id],
    teams: %i[name],
    triages: %i[performed_by_user_id status],
    vaccination_records: %i[outcome session_id]
  }.freeze

  AVAILABLE_DETAILS_CONFIG = {
    changesets: %i[import_id import_type],
    class_imports: %i[
      changed_record_count
      csv_filename
      exact_duplicate_record_count
      new_record_count
      processed_at
      rows_count
      status
      year_groups
    ],
    cohort_imports: %i[
      changed_record_count
      csv_filename
      exact_duplicate_record_count
      new_record_count
      processed_at
      rows_count
      status
    ],
    consents: %i[
      invalidated_at
      programme_type
      response
      route
      updated_at
      withdrawn_at
    ],
    gillick_assessments: %i[],
    notify_log_entries: %i[purpose],
    patient_locations: %i[academic_year date_range location_id],
    pds_search_results: %i[step],
    school_move_log_entries: %i[school_id user_id],
    school_moves: %i[school_id source],
    sessions: %i[academic_year location_id slug],
    teams: %i[name],
    triages: %i[invalidated_at performed_by_user_id status updated_at],
    vaccination_records: %i[
      discarded_at
      nhs_immunisations_api_synced_at
      outcome
      performed_at
      protocol
      session_id
      source
      updated_at
      uuid
    ]
  }.freeze

  AVAILABLE_DETAILS_CONFIG_PII = {
    changesets: %i[pds_nhs_number uploaded_nhs_number],
    gillick_assessments: %i[
      knows_consequences
      knows_delivery
      knows_disease
      knows_side_effects
      knows_vaccination
    ],
    parent_relationships: %i[other_name type],
    parents: %i[email full_name phone],
    pds_search_results: %i[nhs_number]
  }.freeze

  AVAILABLE_DETAILS_CONFIG_WITH_PII =
    AVAILABLE_DETAILS_CONFIG.merge(
      AVAILABLE_DETAILS_CONFIG_PII
    ) { |_, base_fields, pii_fields| (base_fields + pii_fields).uniq }

  DEFAULT_AUDITS_CONFIG = {
    include_associated_audits: true,
    include_filtered_audit_changes: false
  }.freeze

  ALLOWED_AUDITED_CHANGES = %i[
    date_of_death_recorded_at
    gp_practice_id
    home_educated
    invalidated_at
    location_id
    organisation_id
    outcome
    parent_id
    patient_id
    performed_by_user_id
    programme_id
    registration_academic_year
    response
    restricted_at
    rows_count
    route
    school_id
    session_id
    source
    status
    team_id
    uploaded_by_user_id
    user_id
    vaccine_id
    withdrawn_at
    year_groups
  ].freeze

  ALLOWED_AUDITED_CHANGES_PII = %i[
    address_line_1
    address_line_2
    address_postcode
    address_town
    birth_academic_year
    date_of_birth
    date_of_death
    email
    family_name
    full_name
    gender_code
    given_name
    nhs_number
    pending_changes
    phone
    preferred_family_name
    preferred_given_name
    registration
    updated_from_pds_at
  ].freeze

  ALLOWED_AUDITED_CHANGES_WITH_PII =
    (ALLOWED_AUDITED_CHANGES + ALLOWED_AUDITED_CHANGES_PII).uniq.freeze

  def initialize(patient, details_config: {}, audit_config: {}, show_pii: false)
    @patient = patient
    @patient_id = @patient.id
    @patient_events = patient_events(@patient)
    @additional_events = additional_events(@patient)
    @detail_config = extract_detail_config(details_config)
    @events = []
    @audit_config = audit_config
    @show_pii = show_pii
  end

  def render_timeline(*event_names, truncate_columns: false)
    load_grouped_events(event_names)
    format_timeline_console(truncate_columns)
  end

  def additional_events(patient)
    patient_imports = @patient_events[:class_imports]
    patient_sessions = @patient_events[:sessions]
    patient_locations =
      Location.joins(:sessions).where(sessions: { id: patient_sessions })
    class_imports = ClassImport.where(location_id: patient_locations)
    class_imports =
      class_imports.where.not(id: patient_imports) if patient_imports.present?

    {
      class_imports:
        class_imports
          .pluck(:location_id, :id)
          .group_by(&:first)
          .transform_values { |ids| ids.map(&:last) },
      cohort_imports:
        CohortImport
          .where(team_id: patient.teams.select(:id))
          .where.not(id: @patient_events[:cohort_imports])
          .pluck(:id)
    }
  end

  def patient_events(patient)
    {
      class_imports: patient.class_imports.pluck(:id),
      cohort_imports: patient.cohort_imports.pluck(:id),
      sessions: patient.sessions.pluck(:id)
    }
  end

  def extract_detail_config(detail_config)
    detail_config.deep_symbolize_keys
  end

  def details
    @detail_config
  end

  def audits
    @audits ||= DEFAULT_AUDITS_CONFIG.merge(@audit_config)
  end

  def load_events(event_names)
    event_names.each do |event_name|
      event_type = event_name.to_sym

      if details.key?(event_type)
        fields = details[event_type]
        records = @patient.send(event_type)
        records = Array(records)

        records.each do |record|
          event_details =
            fields.each_with_object({}) do |field, hash|
              field_value = record.send(field)
              hash[field.to_s] = field_value.nil? ? "nil" : field_value
            end
          @events << {
            event_type: record.class.name,
            id: record.id,
            details: event_details,
            created_at: record.created_at
          }
        end
      else
        custom_event_handler(event_type)
      end
    end
    @events.sort_by! { |event| event[:created_at] }.reverse!
  end

  def load_grouped_events(event_names)
    load_events(event_names)
    @grouped_events =
      @events.group_by do |event|
        event[:created_at].strftime(Date::DATE_FORMATS[:long])
      end
  end

  def load_timeline_events(event_names)
    load_grouped_events(event_names)

    formatted_items = []

    @grouped_events.each do |date, events|
      formatted_items << { type: :section_header, date: date }

      events.each do |event|
        formatted_items << {
          type: :event,
          event_type: event[:event_type],
          id: event[:id],
          details: event[:details],
          created_at: event[:created_at],
          active: false,
          is_past_item: true
        }
      end
    end
    formatted_items
  end

  def custom_event_handler(event_type)
    case event_type
    when :org_cohort_imports
      @events += org_cohort_imports_events
    when /^add_class_imports_\d+$/ # e.g. add_class_imports_123
      location_id = event_type.to_s.split("_").last
      @events += add_class_imports_events(location_id)
    when :audits
      @events += audits_events
    else
      warn "No handler for event type: #{event_type}"
    end
  end

  def org_cohort_imports_events
    CohortImport
      .where(id: @additional_events[:cohort_imports])
      .map do |cohort_import|
        {
          event_type: "CohortImport",
          id: cohort_import.id,
          details: "excluding patient",
          created_at: cohort_import.created_at
        }
      end
  end

  def add_class_imports_events(location_id)
    ClassImport
      .where(id: @additional_events[:class_imports][location_id.to_i])
      .map do |class_import|
        {
          event_type: "ClassImport",
          id: class_import.id,
          details: {
            location_id: "#{class_import.location_id}, excluding patient"
          },
          created_at: class_import.created_at.to_time
        }
      end
  end

  def audits_events
    audit_events =
      (
        if audits[:include_associated_audits]
          @patient.own_and_associated_audits
        else
          @patient.audits
        end
      ).reject { it.audited_changes.keys == ["updated_from_pds_at"] }

    allowed_changes =
      @show_pii ? ALLOWED_AUDITED_CHANGES_WITH_PII : ALLOWED_AUDITED_CHANGES

    audit_events.map do |audit|
      filtered_changes =
        audit
          .audited_changes
          .each_with_object({}) do |(key, value), hash|
            if allowed_changes.include?(key.to_sym)
              hash[key] = value
            elsif audits[:include_filtered_audit_changes]
              hash[key] = "[FILTERED]"
            end
          end

      event_type = "#{audit.auditable_type}-Audit"

      event_details = { action: audit.action }
      event_details[
        :audited_changes
      ] = filtered_changes.deep_symbolize_keys unless filtered_changes.empty?
      event_details[:auditable_id] = audit.auditable_id

      {
        event_type: event_type,
        id: audit.id,
        details: event_details,
        created_at: audit.created_at
      }
    end
  end

  def format_timeline_console(truncate_columns)
    event_type_width = 25
    details_width = 50
    header_format =
      if truncate_columns
        "%-12s %-10s %-#{event_type_width}s %-12s %-#{details_width}s"
      else
        "%-12s %-10s %-20s %-10s %-s"
      end
    puts sprintf(
           header_format,
           "DATE",
           "TIME",
           "EVENT_TYPE",
           "EVENT-ID",
           "DETAILS"
         )
    puts "-" * 115

    @grouped_events.each do |date, events|
      puts "=== #{date} ===\n" + "-" * 115
      events.each do |event|
        time = event[:created_at].strftime("%H:%M:%S")
        event_type = event[:event_type].to_s
        event_id = event[:id].to_s
        details_string =
          if event[:details].is_a?(Hash)
            event[:details].map { |k, v| "#{k}: #{v}" }.join(", ")
          else
            event[:details].to_s
          end
        if truncate_columns
          event_type = event_type.ljust(event_type_width)[0...event_type_width]
          details = details_string.ljust(details_width)[0...details_width]
        else
          details = details_string
        end
        puts sprintf(header_format, "", time, event_type, event_id, details)
      end
    end
    nil
  end
end
