# frozen_string_literal: true

class AppChildSummaryComponent < ViewComponent::Base
  def initialize(
    child,
    current_team: nil,
    show_add_parent: false,
    show_parents: false,
    show_school_and_year_group: true,
    change_links: {},
    remove_links: {}
  )
    @child = child
    @current_team = current_team
    @show_parents = show_parents
    @show_add_parent = show_add_parent
    @show_school_and_year_group = show_school_and_year_group
    @change_links = change_links
    @remove_links = remove_links
  end

  def call
    tag.div do
      safe_join(
        [
          govuk_summary_list(
            actions:
              @change_links.present? || @remove_links.present? ||
                pds_search_history_link.present?
          ) do |summary_list|
            summary_list.with_row do |row|
              row.with_key { "NHS number" }
              row.with_value { format_nhs_number }
              if (href = @change_links[:nhs_number])
                row.with_action(
                  text: "Change",
                  href:,
                  visually_hidden_text: "NHS number"
                )
              elsif (href = pds_search_history_link)
                row.with_action(text: "PDS history", href:)
              end
            end

            if archive_reason && !@current_team.has_national_reporting_access?
              summary_list.with_row do |row|
                row.with_key { "Archive reason" }
                row.with_value { format_archive_reason }
              end
            end

            summary_list.with_row do |row|
              row.with_key { "Full name" }
              row.with_value { format_full_name }
            end
            if @child.has_preferred_name? || @child.preferred_full_name_changed?
              summary_list.with_row do |row|
                row.with_key { "Known as" }
                row.with_value { format_preferred_full_name }
              end
            end
            summary_list.with_row do |row|
              row.with_key { "Date of birth" }
              row.with_value { format_date_of_birth }
            end
            if @child.ethnic_group.present?
              summary_list.with_row do |row|
                row.with_key { "Ethnicity" }
                row.with_value { format_ethnic_group_and_background(@child) }
                if (href = @change_links[:ethnicity])
                  row.with_action(
                    text: "Change",
                    href:,
                    visually_hidden_text: "Ethnicity"
                  )
                end
              end
            end
            if @child.try(:deceased?)
              summary_list.with_row do |row|
                row.with_key { "Date of death" }
                row.with_value { format_date_of_death }
              end
            end
            if @child.respond_to?(:gender_code)
              summary_list.with_row do |row|
                row.with_key { "Gender" }
                row.with_value { format_gender_code }
              end
            end
            unless @child.try(:restricted?)
              summary_list.with_row do |row|
                row.with_key { "Address" }
                row.with_value { format_address }
              end
            end
            if @show_school_and_year_group
              summary_list.with_row do |row|
                row.with_key { "School" }
                row.with_value { format_school }
                if (href = @change_links[:school])
                  row.with_action(
                    text: "Change",
                    href:,
                    visually_hidden_text: "School"
                  )
                end
              end
              if @child.respond_to?(:year_group)
                summary_list.with_row do |row|
                  row.with_key { "Year group" }
                  row.with_value { format_year_group }
                end
              end
            end
            if (gp_practice = @child.try(:gp_practice))
              summary_list.with_row do |row|
                row.with_key { "GP surgery" }
                row.with_value { gp_practice.name }
              end
            end
            if @show_parents && !@child.restricted?
              @child
                .parent_relationships
                .includes(:parent)
                .find_each do |parent_relationship|
                  summary_list.with_row do |row|
                    row.with_key do
                      parent_relationship.ordinal_label.upcase_first
                    end
                    row.with_value do
                      format_parent_with_relationship(parent_relationship)
                    end

                    if (
                         href =
                           @change_links.dig(
                             :parent,
                             parent_relationship.parent_id
                           )
                       )
                      row.with_action(
                        text: "Edit",
                        href:,
                        visually_hidden_text: parent_relationship.ordinal_label
                      )
                    end

                    if (
                         href =
                           @remove_links.dig(
                             :parent,
                             parent_relationship.parent_id
                           )
                       )
                      row.with_action(
                        text: "Remove",
                        href:,
                        visually_hidden_text: parent_relationship.ordinal_label
                      )
                    end
                  end
                end
            end
          end,
          @show_add_parent ? add_parent_button : nil
        ].compact
      )
    end
  end

  private

  delegate :format_address_multi_line,
           :format_ethnic_group_and_background,
           :format_parent_with_relationship,
           :govuk_button_to,
           :govuk_summary_list,
           :patient_date_of_birth,
           :patient_nhs_number,
           :patient_school,
           :patient_year_group,
           to: :helpers

  def add_parent_button
    helpers.link_to(
      "Add parent or guardian",
      new_patient_parent_relationship_path(@child),
      class: "nhsuk-button nhsuk-button--secondary nhsuk-u-margin-bottom-4"
    )
  end

  def academic_year = AcademicYear.pending

  def archive_reason
    @archive_reason ||=
      if @current_team
        ArchiveReason.find_by(team: @current_team, patient: @child)
      end
  end

  def format_nhs_number
    highlight_if(patient_nhs_number(@child), @child.nhs_number_changed?)
  end

  def format_archive_reason
    type_string = archive_reason.human_enum_name(:type)

    if archive_reason.other?
      "#{type_string}: #{archive_reason.other_details}"
    else
      type_string
    end
  end

  def format_full_name
    highlight_if(
      @child.full_name,
      @child.given_name_changed? || @child.family_name_changed?
    )
  end

  def format_preferred_full_name
    highlight_if(
      @child.preferred_full_name,
      @child.preferred_full_name_changed?
    )
  end

  def format_date_of_birth
    highlight_if(patient_date_of_birth(@child), @child.date_of_birth_changed?)
  end

  def format_date_of_death
    highlight_if(
      @child.date_of_death.to_fs(:long),
      @child.date_of_death_changed?
    )
  end

  def format_gender_code
    highlight_if(@child.gender_code.to_s.humanize, @child.gender_code_changed?)
  end

  def format_address
    highlight_if(format_address_multi_line(@child), @child.address_changed?)
  end

  def format_school
    highlight_if(patient_school(@child), @child.school_id_changed?)
  end

  def format_year_group
    highlight_if(
      patient_year_group(@child, academic_year:),
      @child.year_group_changed? || @child.registration_changed?
    )
  end

  def highlight_if(value, condition)
    condition ? tag.span(value, class: "app-highlight") : value
  end

  def pds_search_history_link
    return unless @child.is_a?(Patient) && @child.pds_lookup_match?

    pds_search_history_patient_path(@child)
  end
end
