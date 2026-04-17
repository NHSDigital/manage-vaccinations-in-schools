# frozen_string_literal: true

class VaccinationRecordsExportForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  attr_accessor :team

  attribute :academic_year, :integer
  attribute :programme_type, :string
  attribute :file_format, :string
  attribute :date_from, :date
  attribute :date_to, :date

  validates :academic_year, presence: true
  validates :programme_type, presence: true
  validates :file_format, inclusion: { in: :file_formats }

  def file_formats
    common = %w[mavis systm_one]
    team&.careplus_enabled? ? common + ["careplus"] : common
  end
end
