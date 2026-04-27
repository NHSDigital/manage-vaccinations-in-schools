# frozen_string_literal: true

# == Schema Information
#
# Table name: patient_locations
#
#  id            :bigint           not null, primary key
#  academic_year :integer          not null
#  date_range    :daterange        default(-Infinity...Infinity), not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  patient_id    :bigint           not null
#  school_id     :bigint           not null
#
# Indexes
#
#  idx_on_patient_id_school_id_academic_year_652216fa07    (patient_id,school_id,academic_year) UNIQUE
#  idx_on_school_id_academic_year_patient_id_c647e75f26    (school_id,academic_year,patient_id) UNIQUE
#  index_patient_locations_on_location_id                  (location_id)
#  index_patient_locations_on_school_id                    (school_id)
#  index_patient_locations_on_school_id_and_academic_year  (school_id,academic_year)
#
# Foreign Keys
#
#  fk_rails_...  (patient_id => patients.id)
#  fk_rails_...  (school_id => locations.id)
#

class PatientLocation < ApplicationRecord
  self.ignored_columns = %i[location_id]

  audited associated_with: :patient
  has_associated_audits

  belongs_to :patient
  belongs_to :school, class_name: "Location"

  has_and_belongs_to_many :immunisation_imports

  scope :current, -> { where(academic_year: AcademicYear.current) }
  scope :pending, -> { where(academic_year: AcademicYear.pending) }

  scope :active, -> { where("date_range @> ?::date", Date.current) }

  scope :joins_team_locations, -> { references(:teams_locations).joins(<<-SQL) }
    INNER JOIN team_locations
    ON team_locations.location_id = patient_locations.school_id
    AND team_locations.academic_year = patient_locations.academic_year
  SQL

  scope :joins_teams, -> { references(:teams).joins(<<-SQL) }
    INNER JOIN teams
    ON teams.id = team_locations.team_id
  SQL

  scope :joins_sessions, -> { joins_team_locations.joins(<<-SQL) }
    INNER JOIN sessions
    ON sessions.team_location_id = team_locations.id
    AND (sessions.dates = '{}' OR patient_locations.date_range @> ANY(sessions.dates))
  SQL

  scope :appear_in_programmes,
        ->(programmes) do
          where(
            Location::ProgrammeYearGroup
              .joins(:location_year_group)
              .where(
                "location_year_groups.location_id = patient_locations.school_id"
              )
              .where(
                "location_year_groups.academic_year = patient_locations.academic_year"
              )
              .where(
                "location_year_groups.value = " \
                  "patient_locations.academic_year - patients.birth_academic_year - ?",
                Integer::AGE_CHILDREN_START_SCHOOL
              )
              .for_programmes(programmes)
              .arel
              .exists
          )
        end

  def begin_date
    value = date_range.begin
    return nil if value.nil? || value == -Float::INFINITY
    value
  end

  def end_date
    value = date_range.end
    return nil if value.nil? || value == Float::INFINITY
    date_range.exclude_end? ? value - 1.day : value
  end

  def begin_date=(value)
    self.date_range = Range.new(value, end_date)
  end

  def end_date=(value)
    self.date_range = Range.new(begin_date, value)
  end

  ##
  # Extend the date range of this patient location to ensure that the +date+
  # is within the range.
  #
  # If the +begin_date+ or +end_date+ are +nil+, they will be left alone since
  # the +date+ would already be considered within the range.
  def extend_date_range_to(date)
    self.begin_date = [date, begin_date].min unless begin_date.nil?

    self.end_date = [date, end_date].max unless end_date.nil?
  end
end
