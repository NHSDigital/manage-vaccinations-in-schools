# frozen_string_literal: true

# == Schema Information
#
# Table name: vaccination_records_exports
#
#  id             :bigint           not null, primary key
#  academic_year  :integer          not null
#  date_from      :date
#  date_to        :date
#  file_format    :string           not null
#  programme_type :string           not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
class VaccinationRecordsExport < ApplicationRecord
  include BelongsToProgramme

  has_one :export, as: :exportable, touch: true
  delegate :team, to: :export, allow_nil: true

  def file_type = :csv

  def type_label = "Vaccination records"

  def name
    base = "#{programme.name} vaccination records"
    return base unless date_from || date_to

    "#{base} (#{date_from_str} to #{date_to_str})"
  end

  def filename
    "#{programme.name} - #{file_format} - #{date_from_str} - #{date_to_str}.csv"
  end

  def generate_file
    exporter_class = {
      "careplus" => Reports::ManualCareplusExporter,
      "mavis" => Reports::ProgrammeVaccinationsExporter,
      "systm_one" => Reports::SystmOneExporter
    }.fetch(file_format)

    exporter_class.call(
      team:,
      programme:,
      academic_year:,
      start_date: date_from,
      end_date: date_to
    )
  end

  private

  def date_from_str = date_from&.to_fs(:long) || "earliest"

  def date_to_str = date_to&.to_fs(:long) || "latest"
end
