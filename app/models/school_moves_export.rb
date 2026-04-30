# frozen_string_literal: true

# == Schema Information
#
# Table name: school_moves_exports
#
#  id         :bigint           not null, primary key
#  date_from  :date
#  date_to    :date
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
class SchoolMovesExport < ApplicationRecord
  has_one :export, as: :exportable, touch: true
  delegate :team, to: :export, allow_nil: true

  def file_type = :csv

  def type_label = "School moves"

  def name = "School moves"

  def filename
    parts = ["school_moves_export"]
    parts << date_from.to_fs(:govuk) if date_from.present?
    parts << "to" if date_from.present? && date_to.present?
    parts << date_to.to_fs(:govuk) if date_to.present?
    "#{parts.join("_")}.csv"
  end

  def generate_file
    Reports::SchoolMovesExporter.new(
      team:,
      start_date: date_from,
      end_date: date_to
    ).csv_data
  end
end
