# frozen_string_literal: true

# == Schema Information
#
# Table name: school_moves
#
#  id            :bigint           not null, primary key
#  academic_year :integer          not null
#  home_educated :boolean
#  source        :integer          not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  patient_id    :bigint           not null
#  school_id     :bigint
#  team_id       :bigint
#
# Indexes
#
#  index_school_moves_on_patient_id                (patient_id) UNIQUE
#  index_school_moves_on_patient_id_and_school_id  (patient_id,school_id)
#  index_school_moves_on_school_id                 (school_id)
#  index_school_moves_on_team_id                   (team_id)
#
# Foreign Keys
#
#  fk_rails_...  (patient_id => patients.id)
#  fk_rails_...  (school_id => locations.id)
#  fk_rails_...  (team_id => teams.id)
#
class SchoolMove < ApplicationRecord
  include Schoolable

  audited associated_with: :patient

  belongs_to :patient

  belongs_to :team, optional: true

  has_many :school_team_locations,
           -> do
             where(academic_year: it.academic_year).order(created_at: :desc)
           end,
           through: :school,
           source: :team_locations,
           class_name: "TeamLocation"

  has_many :school_teams,
           through: :school_team_locations,
           source: :team,
           class_name: "Team"

  scope :joins_team_locations_for_school, -> { joins(<<-SQL) }
    INNER JOIN team_locations
    ON team_locations.location_id = school_moves.school_id
    AND team_locations.academic_year = school_moves.academic_year
  SQL

  enum :source,
       { parental_consent_form: 0, class_list_import: 1, cohort_import: 2 },
       prefix: true,
       validate: true

  validates :team,
            presence: {
              if: -> { school.nil? }
            },
            absence: {
              unless: -> { school.nil? }
            }

  def confirm!(user: nil)
    ActiveRecord::Base.transaction do
      move_across_teams = from_another_team?

      update_patient!
      update_archive_reasons!(user:)
      update_locations!

      log_entry = create_log_entry!(user:)

      update_patient_teams!
      update_patient_statuses!

      if move_across_teams
        create_important_notice!(log_entry)
        update_important_notices!
      end

      destroy! if persisted?
    end
  end

  def ignore!
    destroy! if persisted?
  end

  def from_another_team?
    current_teams = patient.teams_via_patient_locations

    return false if current_teams.empty?

    new_teams =
      if school
        school_teams
      elsif team
        [team]
      end

    (new_teams & current_teams).empty?
  end

  private

  # TODO: Remove these once we've dropped the `team_id` and `home_educated`
  #  columns.
  def destination_school
    @destination_school ||=
      school ||
        (home_educated ? team.home_educated_school : team.unknown_school)
  end

  def destination_teams
    @destination_teams ||= school_id.present? ? school_teams : [team]
  end

  def update_patient!
    patient.update!(home_educated: nil, school: destination_school)
  end

  def update_archive_reasons!(user:)
    new_team_ids = (school_teams.map(&:id) + [team_id]).compact

    patient.archive_reasons.where(team_id: new_team_ids).destroy_all

    archive_reasons =
      patient.teams.find_each.filter_map do |team|
        next if team.id.in?(new_team_ids)

        ArchiveReason.new(
          patient_id:,
          team_id: team.id,
          type: "moved_out_of_area",
          created_by: user
        )
      end

    ArchiveReason.import!(archive_reasons, on_duplicate_key_ignore: true).ids
  end

  def update_locations!
    patient_locations = []

    location = destination_school

    # TODO: Remove this once we add patients to clinics individually.
    #  This is stop patients being taken out of the generic clinic when we add
    #  them to the unknown or home-educated school location.
    source_locations =
      (
        if location.generic_school?
          ([location] + destination_teams.map(&:generic_clinic))
        else
          [location]
        end
      )

    patient
      .patient_locations
      .where("academic_year >= ?", academic_year)
      .where.not(location: source_locations)
      .find_each do |patient_location|
        end_date = Date.yesterday

        patient_location.end_date = end_date

        # It is possible for a patient to join and school and then at some
        #  point later that day be removed from it.
        if patient_location.begin_date && patient_location.begin_date > end_date
          patient_location.begin_date = end_date
        end

        patient_locations << patient_location
      end

    PatientLocation
      .find_or_initialize_by(patient:, location:, academic_year:)
      .tap do |patient_location|
        patient_location.end_date = nil

        # We only want to change the date if this is a new patient location
        #  for this patient, or if the existing patient location already has
        #  a start date. This is because if there's an existing patient
        #  location without a start date, changing the date will take the
        #  patient out of existing sessions.
        if patient_location.new_record? || patient_location.begin_date&.past?
          patient_location.begin_date = Date.current
        end

        patient_locations << patient_location
      end

    # TODO: Remove this once we add patients to clinics individually.
    if location.generic_school?
      destination_teams.each do |destination_team|
        PatientLocation
          .find_or_initialize_by(
            patient:,
            location: destination_team.generic_clinic,
            academic_year:
          )
          .tap do |patient_location|
            patient_location.end_date = nil

            # We only want to change the date if this is a new patient location
            #  for this patient, or if the existing patient location already has
            #  a start date. This is because if there's an existing patient
            #  location without a start date, changing the date will take the
            #  patient out of existing sessions.
            if patient_location.new_record? ||
                 patient_location.begin_date&.past?
              patient_location.begin_date = Date.current
            end

            patient_locations << patient_location
          end
      end
    end

    PatientLocation.import!(
      patient_locations,
      on_duplicate_key_update: {
        conflict_target: %i[patient_id location_id academic_year],
        columns: %i[date_range]
      }
    )
  end

  def create_log_entry!(user:)
    SchoolMoveLogEntry.create!(
      patient:,
      school_id: destination_school.id,
      user:
    )
  end

  def create_important_notice!(school_move_log_entry)
    new_team_ids = (school_teams.map(&:id) + [team_id]).compact

    patient.teams.each do |team|
      next if team.id.in?(new_team_ids)

      ImportantNotice.team_changed.find_or_create_by!(
        patient:,
        team:,
        type: :team_changed,
        recorded_at: school_move_log_entry.created_at,
        school_move_log_entry:
      )
    end
  end

  def update_patient_teams!
    PatientTeamUpdater.call(patient:)
  end

  def update_patient_statuses!
    PatientStatusUpdater.call(patient:)
  end

  def update_important_notices!
    ImportantNoticeGeneratorJob.perform_later([patient.id])
  end
end
