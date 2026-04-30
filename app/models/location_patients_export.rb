# frozen_string_literal: true

# == Schema Information
#
# Table name: location_patients_exports
#
#  id            :bigint           not null, primary key
#  academic_year :integer          not null
#  filter_params :jsonb            not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  location_id   :bigint           not null
#
# Foreign Keys
#
#  fk_rails_...  (location_id => locations.id)
#
class LocationPatientsExport < ApplicationRecord
  belongs_to :location
  has_one :export, as: :exportable, touch: true
  delegate :team, to: :export, allow_nil: true

  def file_type = :xlsx

  def type_label = "Offline session"

  def name
    "#{location.name} offline session"
  end

  def filename
    "#{name} - exported on #{Date.current.to_fs(:long)}.xlsx"
  end

  def generate_file
    filter =
      PatientFilter.new(team:, academic_year:, **filter_params.symbolize_keys)
    patients, programmes =
      location.school? ? school_patients(filter) : clinic_patients(filter)
    Reports::OfflineExporter.from_patients(
      patients,
      team:,
      programmes:,
      academic_year:
    )
  end

  private

  def school_patients(filter)
    scope =
      Patient
        .joins(:patient_locations)
        .where(patient_locations: { location:, academic_year: })
        .where(school: location)
        .includes_statuses
    [filter.apply(scope), location.programmes]
  end

  def clinic_patients(filter)
    [filter.apply(Patient.includes_statuses), team.programmes]
  end
end
