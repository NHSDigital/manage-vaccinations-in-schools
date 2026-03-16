# frozen_string_literal: true

class Reports::OfflineExporter
  include Reports::ExportFormatters
  include TriagesHelper

  def initialize(
    team:,
    programmes:,
    academic_year:,
    patients:,
    dates:,
    include_psd:,
    programmes_for:,
    location:,
    session_id:
  )
    @team = team
    @programmes = programmes
    @academic_year = academic_year
    @patients =
      patients.includes(
        :programme_statuses,
        :school,
        parent_relationships: :parent,
        vaccination_records: %i[performed_by_user vaccine session]
      ).order_by_name
    @dates = dates
    @include_psd = include_psd
    @programmes_for = programmes_for
    @location = location
    @session_id = session_id
    @vaccines = {}
    @batches = {}
  end

  def call
    # stree-ignore
    Axlsx::Package
      .new { |package|
        package.use_shared_strings = true

        add_vaccinations_sheet(package)
        add_reference_sheet(package,
                            name: "Performing Professionals",
                            values_name: "EMAIL",
                            values: performing_professional_email_values)
        add_reference_sheet(package,
                            name: "Suppliers",
                            values_name: "EMAIL",
                            values: supplier_email_values)
        add_batch_numbers_sheets(package)
      }
      .to_stream
      .read
  end

  def self.from_session(session)
    new(
      team: session.team,
      programmes: session.programmes,
      academic_year: session.academic_year,
      patients: session.patients,
      dates: session.dates,
      include_psd: session.psd_enabled?,
      programmes_for: ->(patient) { session.programmes_for(patient:) },
      location: session.location,
      session_id: session.id
    ).call
  end

  private_class_method :new

  private

  attr_reader :team,
              :programmes,
              :academic_year,
              :patients,
              :dates,
              :include_psd,
              :programmes_for,
              :location,
              :session_id

  delegate :organisation, to: :team

  def add_vaccinations_sheet(package)
    workbook = package.workbook

    cached_styles = CachedStyles.new(workbook)

    workbook.add_worksheet(name: "Vaccinations") do |sheet|
      sheet.add_row(columns.map { it.to_s.upcase })

      patients.find_each do |patient|
        rows(patient:).each { |row| row.add_to(sheet:, cached_styles:) }
      end

      sheet.sheet_view.pane do |pane|
        pane.top_left_cell = "C2"
        pane.state = :frozen_split
        pane.y_split = 1
        pane.x_split = 2
        pane.active_pane = :bottom_right
      end
    end
  end

  def add_reference_sheet(package, name:, values_name:, values:)
    workbook = package.workbook
    workbook.add_worksheet(name:, state: :hidden) do |sheet|
      sheet.sheet_protection

      sheet.add_row([values_name])

      values.each { |value| sheet.add_row([value]) }
    end
  end

  def add_batch_numbers_sheets(package)
    programmes.map do |programme|
      add_reference_sheet package,
                          name: "#{programme.type} Batch Numbers",
                          values_name: "NUMBER",
                          values: batch_values_for_programme(programme)
    end
  end

  def columns
    @columns ||=
      %i[
        person_forename
        person_surname
        organisation_code
        school_name
        clinic_name
        care_setting
        person_dob
        year_group
        registration
        person_gender_code
        person_address_line_1
        person_postcode
        nhs_number
        consent_status
        consent_details
        health_question_answers
        triage_status
        triaged_by
        triage_date
        triage_notes
        gillick_status
        gillick_assessment_date
        gillick_assessed_by
        gillick_assessment_notes
      ] + (include_psd ? [:psd_status] : []) +
        %i[
          vaccinated
          date_of_vaccination
          time_of_vaccination
          programme
          vaccine_given
          performing_professional_email
          supplier_email
          batch_number
          batch_expiry_date
          anatomical_site
          dose_sequence
          reason_not_vaccinated
          notes
          session_id
          uuid
        ]
  end

  def consents
    @consents ||=
      Consent
        .where(academic_year:, patient_id: patients.select(:id))
        .not_invalidated
        .includes(:parent, patient: { parent_relationships: :parent })
        .group_by(&:patient_id)
        .transform_values do |consents_for_patient|
          consents_for_patient
            .group_by(&:programme_type)
            .each_with_object({}) do |(programme_type, consents), hash|
              hash[programme_type] = ConsentGrouper.call(
                consents,
                programme_type:,
                academic_year:
              )
            end
        end
  end

  def gillick_assessments
    @gillick_assessments ||=
      GillickAssessment
        .select(
          "DISTINCT ON (patient_id, programme_type) gillick_assessments.*"
        )
        .where(patient_id: patients.select(:id), date: dates)
        .order(:patient_id, :programme_type, created_at: :desc)
        .includes(:performed_by)
        .group_by(&:patient_id)
        .transform_values do
          it.group_by(&:programme_type).transform_values(&:first)
        end
  end

  def patient_specific_directions
    @patient_specific_directions ||=
      PatientSpecificDirection
        .select(
          "DISTINCT ON (patient_id, programme_type) patient_specific_directions.*"
        )
        .where(academic_year:, patient_id: patients.select(:id))
        .not_invalidated
        .order(:patient_id, :programme_type, created_at: :desc)
        .includes(:created_by)
        .group_by(&:patient_id)
        .transform_values do
          it.group_by(&:programme_type).transform_values(&:first)
        end
  end

  def triages
    @triages ||=
      Triage
        .select("DISTINCT ON (patient_id, programme_type) triages.*")
        .where(academic_year:, patient_id: patients.select(:id))
        .not_invalidated
        .order(:patient_id, :programme_type, created_at: :desc)
        .includes(:performed_by)
        .group_by(&:patient_id)
        .transform_values do
          it.group_by(&:programme_type).transform_values(&:first)
        end
  end

  def rows(patient:)
    programmes_for
      .call(patient)
      .flat_map do |programme|
        programme_status = patient.programme_status(programme, academic_year:)

        bg_color =
          if programme_status.consent_refused?
            "F7D4D1"
          elsif programme_status.consent_conflicts?
            "FFDC8E"
          end

        row_style = {
          strike: patient.invalidated?,
          bg_color:,
          border: {
            style: :thin,
            color: "000000"
          }
        }

        vaccination_records =
          patient.vaccination_records.to_a.select do
            it.programme_type == programme.type
          end

        if vaccination_records.any?
          vaccination_records.map do |vaccination_record|
            Row.new(columns, style: row_style) do |row|
              add_patient_cells(row, patient:, programme:)
              add_existing_row_cells(row, vaccination_record:)
            end
          end
        else
          [
            Row.new(columns, style: row_style) do |row|
              add_patient_cells(row, patient:, programme:)
              add_new_row_cells(row, patient:, programme:)
            end
          ]
        end
      end
  end

  def add_patient_cells(row, patient:, programme:)
    gillick_assessment = gillick_assessments.dig(patient.id, programme.type)
    grouped_consents = consents.dig(patient.id, programme.type) || []
    patient_specific_direction =
      patient_specific_directions.dig(patient.id, programme.type)
    triage = triages.dig(patient.id, programme.type)

    row[:person_forename] = patient.given_name
    row[:person_surname] = patient.family_name
    row[:person_dob] = patient.date_of_birth
    row[:year_group] = patient.year_group(academic_year:)
    row[:registration] = patient.registration
    row[:person_gender_code] = Cell.new(
      patient.gender_code.humanize,
      allowed_values: Patient.gender_codes.keys
    )
    row[:person_address_line_1] = (
      patient.address_line_1 unless patient.restricted?
    )
    row[:person_postcode] = (
      patient.address_postcode unless patient.restricted?
    )
    row[:nhs_number] = patient.nhs_number
    row[:consent_status] = consent_status(patient:, programme:, academic_year:)
    row[:consent_details] = consent_details(consents: grouped_consents)
    row[:health_question_answers] = Cell.new(
      health_question_answers(consents: grouped_consents),
      style: {
        alignment: {
          wrap_text: true
        }
      }
    )
    row[:triage_status] = triage_status_text(triage)
    row[:triaged_by] = triage&.performed_by&.full_name
    row[:triage_date] = triage&.created_at
    row[:triage_notes] = triage&.notes
    row[:gillick_status] = gillick_status(gillick_assessment:)
    row[:gillick_assessment_date] = gillick_assessment&.created_at
    row[:gillick_assessed_by] = gillick_assessment&.performed_by&.full_name
    row[:gillick_assessment_notes] = gillick_assessment&.notes

    row[:psd_status] = psd_status(patient_specific_direction:) if include_psd
  end

  def add_existing_row_cells(row, vaccination_record:)
    patient = vaccination_record.patient
    programme = vaccination_record.programme
    session = vaccination_record.session
    vaccine = vaccination_record.vaccine
    location = session&.location

    row[:organisation_code] = vaccination_record.performed_ods_code

    row[:vaccinated] = Cell.new(
      vaccinated(vaccination_record:),
      allowed_values: %w[Y N]
    )
    row[:school_name] = (
      if location
        school_name(location:, patient:)
      else
        vaccination_record.location_name
      end
    )
    row[:care_setting] = Cell.new(
      location ? care_setting(location:) : nil,
      type: :integer,
      allowed_values: [1, 2]
    )
    row[:date_of_vaccination] = vaccination_record.performed_at.to_date
    row[:time_of_vaccination] = vaccination_record.performed_at.strftime(
      "%H:%M:%S"
    )
    row[:programme] = programme.import_names.first
    row[:vaccine_given] = Cell.new(
      vaccine&.upload_name,
      allowed_values: vaccine_values_for_programme(programme)
    )
    row[:performing_professional_email] = Cell.new(
      vaccination_record.performed_by_user&.email,
      allowed_formula: performing_professionals_range
    )
    row[:supplier_email] = Cell.new(
      vaccination_record.supplied_by&.email,
      allowed_formula: suppliers_range
    )
    row[:batch_number] = Cell.new(
      vaccination_record.batch_number,
      allowed_formula: batch_numbers_range_for_programme(programme)
    )
    row[:batch_expiry_date] = vaccination_record.batch_expiry
    row[:anatomical_site] = Cell.new(
      anatomical_site(vaccination_record:),
      allowed_values: ImmunisationImportRow::DELIVERY_SITES.keys
    )
    row[:dose_sequence] = dose_sequence(vaccination_record:)
    row[:reason_not_vaccinated] = Cell.new(
      reason_not_vaccinated(vaccination_record:),
      allowed_values: ImmunisationImportRow::REASONS_NOT_ADMINISTERED.keys
    )
    row[:notes] = vaccination_record.notes
    row[:session_id] = session&.id
    row[:uuid] = vaccination_record.uuid

    if location&.generic_clinic?
      row[:clinic_name] = Cell.new(
        vaccination_record.location_name,
        allowed_values: clinic_name_values
      )
    end
  end

  def add_new_row_cells(row, patient:, programme:)
    # We're assuming here that the patient is eligible for the default
    # programme, and optionally a variant. This might not be the case in the
    # future, but it works for now.

    programme_variant = programme.variant_for(patient:)

    row[:organisation_code] = organisation.ods_code

    row[:vaccinated] = Cell.new(allowed_values: %w[Y N])
    row[:date_of_vaccination] = Cell.new(type: :date)
    row[:school_name] = school_name(location:, patient:)
    row[:care_setting] = Cell.new(
      (
        if location
          care_setting(location:)
        else
          ImmunisationImportRow::CARE_SETTING_COMMUNITY
        end
      ),
      type: :integer,
      allowed_values: [1, 2]
    )
    row[:programme] = programme_variant.import_names.first
    row[:vaccine_given] = Cell.new(
      allowed_values: vaccine_values_for_programme(programme_variant)
    )
    row[:performing_professional_email] = Cell.new(
      allowed_formula: performing_professionals_range
    )
    row[:supplier_email] = Cell.new(allowed_formula: suppliers_range)
    row[:batch_number] = Cell.new(
      allowed_formula: batch_numbers_range_for_programme(programme)
    )
    row[:batch_expiry_date] = Cell.new(type: :date)
    row[:anatomical_site] = Cell.new(
      allowed_values: ImmunisationImportRow::DELIVERY_SITES.keys
    )
    row[:dose_sequence] = patient.programme_status(
      programme,
      academic_year:
    ).dose_sequence
    row[:reason_not_vaccinated] = Cell.new(
      allowed_values: ImmunisationImportRow::REASONS_NOT_ADMINISTERED.keys
    )

    row[:session_id] = session_id

    if location.nil? || location.generic_clinic?
      row[:clinic_name] = Cell.new(allowed_values: clinic_name_values)
    end
  end

  def vaccine_values_for_programme(programme)
    # We use the variant_type or type strings as the cache key because
    # Programme::Variant delegates identity methods (hash, ==) to the base
    # Programme. Without this, MMR vaccines would be returned for an MMRV
    # variant.
    cache_key = programme.try(:variant_type) || programme.type
    @vaccines[cache_key] ||= Vaccine
      .active
      .for_programmes([programme])
      .pluck(:upload_name)
  end

  def batch_values_for_programme(programme, existing_batch: nil)
    batch_names =
      (
        @batches[programme] ||= team
          .batches
          .not_archived
          .not_expired
          .joins(:vaccine)
          .where(vaccine: { programme_type: programme.type })
          .pluck(:number)
      )

    (batch_names + [existing_batch&.number].compact).uniq
  end

  def performing_professional_email_values
    @performing_professional_email_values ||= team.users.pluck(:email)
  end

  def performing_professionals_range
    count = performing_professional_email_values.count
    "'Performing Professionals'!$A2:$A#{count + 1}"
  end

  def supplier_email_values
    @supplier_email_values ||= team.users.show_in_suppliers.pluck(:email)
  end

  def suppliers_range
    count = supplier_email_values.count
    "'Suppliers'!$A2:$A#{count + 1}"
  end

  def batch_numbers_range_for_programme(programme)
    count = batch_values_for_programme(programme).count
    "'#{programme.type} Batch Numbers'!$A2:$A#{count + 1}"
  end

  def clinic_name_values
    @clinic_name_values ||= team.community_clinics.pluck(:name)
  end

  class CachedStyles
    attr_reader :workbook

    def initialize(workbook)
      @workbook = workbook
      @cache = {}
    end

    def find_or_create(attributes)
      @cache[attributes] ||= workbook.styles.add_style(attributes)
    end
  end

  class Row
    attr_reader :columns, :row_style, :cells

    def initialize(columns, style: {})
      @columns = columns
      @row_style = style
      @cells = columns.map { Cell.new }
      yield self if block_given?
    end

    def []=(column, value)
      index = columns.index(column)
      raise "Column #{column} not in row." if index.nil?

      @cells[index] = (value.is_a?(Cell) ? value : Cell.new(value))
    end

    def add_to(sheet:, cached_styles:)
      row_index = sheet.rows.count

      values = cells.map(&:value)
      types = cells.map(&:type)
      style =
        cells.map { cached_styles.find_or_create(row_style.merge(_1.style)) }
      sheet.add_row(values, types:, style:)

      cells.each_with_index do |cell, column_index|
        cell.add_data_validation_to(sheet:, row_index:, column_index:)
      end
    end
  end

  class Cell
    attr_reader :value, :type, :style, :allowed_values, :allowed_formula

    def initialize(
      value = "",
      type: nil,
      style: {},
      allowed_values: [],
      allowed_formula: nil
    )
      @value = value
      @type = type || Cell.default_type_for(value)
      @style = Cell.default_style_for(@type).merge(style)
      @allowed_values = allowed_values
      @allowed_formula = allowed_formula
    end

    ALPHABET = ("A".."Z").to_a.freeze
    CELL_COLUMNS = ALPHABET + ALPHABET.product(ALPHABET).map { _1 + _2 }

    def add_data_validation_to(sheet:, column_index:, row_index:)
      return if allowed_values.blank? && allowed_formula.blank?

      cell = "#{CELL_COLUMNS[column_index]}#{row_index + 1}"
      formula1 =
        if allowed_values.present?
          "\"#{allowed_values.join(", ")}\""
        elsif allowed_formula.present?
          "=#{allowed_formula}"
        end

      sheet.add_data_validation(
        cell,
        type: :list,
        formula1:,
        hideDropDown: false,
        showErrorMessage: true,
        errorTitle: "",
        error: "Please use the dropdown selector to choose the value",
        errorStyle: :stop,
        showInputMessage: true,
        prompt: "&amp; Choose the value from the dropdown"
      )
    end

    def self.default_type_for(value)
      case value
      when Date
        :date
      when Integer
        :integer
      else
        :string
      end
    end

    def self.default_style_for(type)
      if type == :date
        { format_code: "dd/mm/yyyy" }
      else
        {}
      end
    end
  end
end
