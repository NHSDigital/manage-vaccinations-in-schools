# frozen_string_literal: true

class AppVaccinationRecordSummaryComponent < ViewComponent::Base
  def initialize(
    vaccination_record,
    current_user:,
    change_links: {},
    show_notes: true,
    comparing: false
  )
    @vaccination_record = vaccination_record
    @current_user = current_user
    @change_links = change_links
    @show_notes = show_notes
    @comparing = comparing

    @identity_check = vaccination_record.identity_check
    @patient = vaccination_record.patient
    @programme = vaccination_record.programme
    @vaccine = vaccination_record.vaccine
  end

  def call
    govuk_summary_list(actions: @change_links.present?) do |summary_list|
      summary_list.with_row do |row|
        row.with_key { "Child" }
        row.with_value { @patient.full_name }
      end

      summary_list.with_row do |row|
        row.with_key { "Outcome" }
        row.with_value { outcome_value }

        if (href = @change_links[:outcome])
          row.with_action(
            text: "Change",
            href:,
            visually_hidden_text: "outcome"
          )
        end
      end

      summary_list.with_row do |row|
        row.with_key { "Programme" }
        row.with_value { programme_value }
      end

      if @vaccination_record.administered? &&
           !@vaccination_record.sourced_from_manual_report?
        summary_list.with_row do |row|
          row.with_key { "Vaccine" }

          if @vaccine
            row.with_value { vaccine_value }

            if @current_user.selected_team.has_national_reporting_access?
              row.with_action(
                text: "Change",
                href: @change_links[:batch],
                visually_hidden_text: "vaccine"
              )
            elsif (href = @change_links[:vaccine])
              row.with_action(
                text: "Change",
                visually_hidden_text: "vaccine",
                href:
              )
            end
          elsif (href = @change_links[:vaccine])
            row.with_value { link_to "Add vaccine", href }
          else
            row.with_value { "Not provided" }
          end
        end

        summary_list.with_row do |row|
          row.with_key { "Batch number" }

          if @vaccination_record.batch_number
            row.with_value(classes: ["app-u-code"]) { batch_number_value }

            if (href = @change_links[:batch])
              row.with_action(
                text: "Change",
                href:,
                visually_hidden_text: "batch"
              )
            end
          elsif (href = @change_links[:batch])
            row.with_value { link_to "Add batch", href }
          else
            row.with_value { "Not provided" }
          end
        end

        if @vaccination_record.batch_number && @vaccination_record.batch_expiry
          summary_list.with_row do |row|
            row.with_key { "Batch expiry date" }
            row.with_value { batch_expiry_value }

            if @current_user.selected_team.has_national_reporting_access?
              row.with_action(
                text: "Change",
                href: @change_links[:batch],
                visually_hidden_text: "batch expiry date"
              )
            end
          end
        end

        summary_list.with_row do |row|
          row.with_key { "Method" }

          if @vaccination_record.delivery_method.present?
            row.with_value { delivery_method_value }

            if (href = @change_links[:delivery_method])
              row.with_action(
                text: "Change",
                href:,
                visually_hidden_text: "method"
              )
            end
          elsif (href = @change_links[:delivery_method])
            row.with_value { link_to "Add method", href }
          else
            row.with_value { "Not provided" }
          end
        end

        summary_list.with_row do |row|
          row.with_key { "Site" }

          if @vaccination_record.delivery_site.present?
            row.with_value { delivery_site_value }

            if (href = @change_links[:delivery_site])
              row.with_action(
                text: "Change",
                href:,
                visually_hidden_text: "site"
              )
            end
          elsif (href = @change_links[:delivery_site])
            row.with_value { link_to "Add site", href }
          else
            row.with_value { "Not provided" }
          end
        end
      end

      if @vaccination_record.administered? || @vaccination_record.already_had?
        if @vaccination_record.vaccine.present? &&
             !@vaccination_record.sourced_from_national_reporting?
          summary_list.with_row do |row|
            row.with_key { "Dose volume" }
            row.with_value { dose_volume_value }

            if (href = @change_links[:dose_volume])
              row.with_action(
                text: "Change",
                href:,
                visually_hidden_text: "dose volume"
              )
            end
          end
        end

        summary_list.with_row do |row|
          row.with_key { "Dose number" }
          row.with_value { dose_number_value }
          if (href = @change_links[:dose_sequence])
            row.with_action(
              text: "Change",
              href:,
              visually_hidden_text: "dose number"
            )
          end
        end
      end

      if @identity_check
        summary_list.with_row do |row|
          row.with_key { "Child identified by" }
          row.with_value { identity_check_label(@identity_check) }
          if (href = @change_links[:identity])
            row.with_action(
              text: "Change",
              href:,
              visually_hidden_text: "child identified by"
            )
          end
        end
      end

      summary_list.with_row do |row|
        row.with_key { "Location" }
        row.with_value { location_value }
        if (href = @change_links[:location])
          row.with_action(
            text: "Change",
            href:,
            visually_hidden_text: "location"
          )
        end
      end

      summary_list.with_row do |row|
        row.with_key { "Date" }
        row.with_value { date_value }
        if (href = @change_links[:performed_at])
          row.with_action(text: "Change", visually_hidden_text: "date", href:)
        end
      end

      summary_list.with_row do |row|
        row.with_key { "Time" }
        row.with_value { time_value }
        if (href = @change_links[:performed_at])
          row.with_action(text: "Change", visually_hidden_text: "time", href:)
        end
      end

      if @vaccination_record.supplied_by.present?
        summary_list.with_row do |row|
          row.with_key { "Supplier" }
          row.with_value { supplier_value }
          if (href = @change_links[:supplier])
            row.with_action(
              text: "Change",
              visually_hidden_text: "supplier",
              href:
            )
          end
        end
      end

      summary_list.with_row do |row|
        row.with_key { "Vaccinator" }
        row.with_value { vaccinator_value }
        if (href = @change_links[:vaccinator])
          row.with_action(
            text: "Change",
            visually_hidden_text: "vaccinator",
            href:
          )
        end
      end

      if @vaccination_record.protocol.present? &&
           !@vaccination_record.sourced_from_national_reporting?
        summary_list.with_row do |row|
          row.with_key { "Protocol" }
          row.with_value { protocol_value }
        end
      end

      if @show_notes && !@vaccination_record.sourced_from_national_reporting?
        summary_list.with_row do |row|
          row.with_key { "Notes" }

          if @vaccination_record.notes.present?
            row.with_value { notes_value }

            if (href = @change_links[:notes])
              row.with_action(
                text: "Change",
                href:,
                visually_hidden_text: "notes"
              )
            end
          elsif (href = @change_links[:notes])
            row.with_value { link_to "Add notes", href }
          else
            row.with_value { "Not provided" }
          end
        end
      end

      if @vaccination_record.respond_to?(:discarded_at) &&
           @vaccination_record.discarded_at.present?
        summary_list.with_row do |row|
          row.with_key { "Archived" }
          row.with_value { discarded_value }
        end
      end

      if @vaccination_record.respond_to?(:source)
        summary_list.with_row do |row|
          row.with_key { "Source" }
          row.with_value { source_value }
        end
      end

      if @vaccination_record.reported_by.present?
        summary_list.with_row do |row|
          row.with_key { "Reported by" }
          row.with_value { @vaccination_record.reported_by&.full_name }
        end
      end

      if historical_vaccination_event?
        summary_list.with_row do |row|
          row.with_key { "Reported on" }
          row.with_value { @vaccination_record.created_at.to_fs(:long) }
        end
      end

      correct_feature_flags_enabled =
        Programme.all_as_variants.any? do
          Flipper.enabled?(:imms_api_sync_job, it)
        end && Flipper.enabled?(:imms_api_integration)
      if @vaccination_record.respond_to?(:sync_status) &&
           correct_feature_flags_enabled &&
           @vaccination_record.correct_source_for_nhs_immunisations_api? &&
           !@comparing
        summary_list.with_row do |row|
          row.with_key { "Synced with NHS England?" }
          row.with_value do
            render AppVaccinationRecordAPISyncStatusComponent.new(
                     @vaccination_record
                   )
          end
        end
      end
    end
  end

  private

  delegate :govuk_summary_list,
           :identity_check_label,
           :vaccination_record_location,
           :vaccination_record_source,
           to: :helpers

  def source_value
    highlight_if(
      vaccination_record_source(@vaccination_record),
      @vaccination_record.source_changed?
    )
  end

  def outcome_value
    outcome =
      VaccinationRecord.human_enum_name(:outcome, @vaccination_record.outcome)

    highlight_if(outcome, @vaccination_record.outcome_changed?)
  end

  def programme_value
    highlight_if(@programme.name, @vaccination_record.programme_type_changed?)
  end

  def vaccine_value
    display_name =
      if @current_user.selected_team.has_national_reporting_access?
        @vaccine.nivs_name.presence || @vaccine.brand
      else
        @vaccine.brand
      end
    highlight_if(display_name, @vaccination_record.vaccine_id_changed?)
  end

  def delivery_method_value
    highlight_if(
      VaccinationRecord.human_enum_name(
        :delivery_method,
        @vaccination_record.delivery_method
      ),
      @vaccination_record.delivery_method_changed?
    )
  end

  def delivery_site_value
    highlight_if(
      VaccinationRecord.human_enum_name(
        :delivery_site,
        @vaccination_record.delivery_site
      ),
      @vaccination_record.delivery_site_changed?
    )
  end

  def dose_volume_value
    return "Unknown" if @vaccination_record.dose_volume_ml.blank?

    "#{@vaccination_record.dose_volume_ml} ml"
  end

  def batch_number_value
    highlight_if(
      @vaccination_record.batch_number,
      @vaccination_record.batch_number_changed?
    )
  end

  def batch_expiry_value
    highlight_if(
      @vaccination_record.batch_expiry&.to_fs(:long) || "Unknown",
      @vaccination_record.batch_expiry_changed?
    )
  end

  def location_value
    vaccination_record_location(@vaccination_record)
  end

  def date_value
    date = @vaccination_record.performed_at_date

    highlight_if(
      date.today? ? "Today (#{date.to_fs(:long)})" : date.to_fs(:long),
      @vaccination_record.performed_at_date_changed?
    )
  end

  def time_value
    highlight_if(
      @vaccination_record.performed_at_time&.to_fs(:time) || "Unknown",
      @vaccination_record.performed_at_time_changed?
    )
  end

  def supplier_value
    highlight_if(
      @vaccination_record.supplied_by&.full_name,
      @vaccination_record.supplied_by_user_id_changed?
    )
  end

  def vaccinator_value
    value =
      if @vaccination_record.performed_by == @current_user
        "You (#{@current_user.full_name})"
      elsif @vaccination_record.performed_by
        @vaccination_record.performed_by&.full_name
      else
        "Unknown"
      end

    highlight_if(
      value,
      @vaccination_record.performed_by_family_name_changed? ||
        @vaccination_record.performed_by_given_name_changed? ||
        @vaccination_record.performed_by_user_id_changed?
    )
  end

  def protocol_value
    highlight_if(
      VaccinationRecord.human_enum_name(
        :protocol,
        @vaccination_record.protocol
      ),
      @vaccination_record.protocol_changed?
    )
  end

  def notes_value
    highlight_if(@vaccination_record.notes, @vaccination_record.notes_changed?)
  end

  def dose_number_value
    highlight_if(
      @vaccination_record.dose_sequence&.ordinalize || "Unknown",
      @vaccination_record.dose_sequence_changed?
    )
  end

  def discarded_value
    @vaccination_record&.discarded_at&.to_fs(:long)
  end

  def highlight_if(value, condition)
    condition ? tag.span(value, class: "app-highlight") : value
  end

  def historical_vaccination_event?
    @vaccination_record.sourced_from_historical_upload? ||
      @vaccination_record.sourced_from_manual_report?
  end
end
