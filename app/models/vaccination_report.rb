# frozen_string_literal: true

class VaccinationReport
  include RequestSessionPersistable
  include WizardStepConcern

  attribute :date_from, :date
  attribute :date_to, :date
  attribute :file_format, :string
  attribute :programme_type, :string
  attribute :academic_year, :integer

  def initialize(current_user:, **attributes)
    @current_user = current_user
    super(**attributes)
  end

  def wizard_steps
    %i[dates file_format]
  end

  on_wizard_step :file_format, exact: true do
    validates :file_format, inclusion: { in: :file_formats }
  end

  validates :programme_type,
            :academic_year,
            :file_format,
            presence: true,
            on: :single_page
  validates :file_format, inclusion: { in: :file_formats }, on: :single_page

  def programme
    Programme.find(programme_type) if programme_type
  end

  def programme=(value)
    self.programme_type = value.type
  end

  def csv_data
    exporter_class.call(
      team: @current_user.selected_team,
      programme:,
      academic_year:,
      start_date: date_from,
      end_date: date_to
    )
  end

  def csv_filename
    return nil if invalid?

    from_str = date_from&.to_fs(:long) || "earliest"
    to_str = date_to&.to_fs(:long) || "latest"

    "#{programme.name} - #{file_format} - #{from_str} - #{to_str}.csv"
  end

  def file_formats
    common_file_formats = %w[mavis systm_one]
    if @current_user.selected_team.careplus_enabled?
      common_file_formats + ["careplus"]
    else
      common_file_formats
    end
  end

  private

  def exporter_class
    {
      careplus: Reports::ManualCareplusExporter,
      mavis: Reports::ProgrammeVaccinationsExporter,
      systm_one: Reports::SystmOneExporter
    }.fetch(file_format.to_sym)
  end

  def request_session_key = "vaccination_report"
end
