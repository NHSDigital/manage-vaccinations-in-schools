# frozen_string_literal: true

class AddHomeEducatedAndUnknownSchoolPatientsToSchools < ActiveRecord::Migration[8.1]
  def up
    academic_year = AcademicYear.current

    Patient
      .where(school_id: nil)
      .includes(patient_locations: { location: { team_locations: :team } })
      .find_each do |patient|
      # We need to determine the appropriate team, some patients might be part
      # of multiple teams at the moment.

      patient_locations = patient.patient_locations
        .select { it.academic_year == academic_year }
        .select { it.location.generic_clinic? }
        .sort do |a, b|
          # We need to make a decision about the best patient location to use.
          # If one includes today's date and the other doesn't, then we use the
          # one that includes today's date.

          a_is_today = a.date_range.include?(Date.current)
          b_is_today = b.date_range.include?(Date.current)

          if b_is_today && !a_is_today
            -1
          elsif a_is_today && !b_is_today
            1
          else
            0
          end
        end

      teams = patient_locations.flat_map { it.location.team_locations.map(&:team) }.uniq

      team = teams.last

      if team.nil?
        Rails.logger.warn "Patient #{patient.id} has no team"
        next
      end

      if teams.length == 1
        Rails.logger.info "Patient #{patient.id} assigned to #{team.workgroup}"
      else
        Rails.logger.warn "Patient #{patient.id} assigned to #{team.workgroup} (out of #{teams.length} possibilities)"
      end

      SchoolMove.new(patient:, team:, home_educated: patient.home_educated, academic_year:).confirm!
    end
  end

  def down
    Patient.joins(:school).merge(Location.generic_school).update_all(school_id: nil)
    PatientLocation.joins(:location).merge(Location.generic_school).delete_all
  end
end
