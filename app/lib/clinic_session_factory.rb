# frozen_string_literal: true

##
# This class either finds or creates a suitable community clinic session for
# the team, academic year, and programme type.
#
# It's used when recording a vaccination for a patient outside of the context
# of a school and therefore we need a clinic session to record the vaccination
# from.
class ClinicSessionFactory
  def initialize(team:, academic_year:, programme_type:)
    @team = team
    @academic_year = academic_year
    @programme_type = programme_type
  end

  def call
    ActiveRecord::Base.transaction do
      session = existing_session || new_session

      unless session.has_programme_type?(programme_type)
        session.sync_location_programme_year_groups!(
          programme_types:
            (session.programme_types + [programme_type]).sort.uniq
        )

        # This is needed because `programme_types` is memoized when it's called above.
        session.reload
        session.instance_variable_set(:@programme_types, nil)
      end

      session
    end
  end

  def self.call(...) = new(...).call

  private_class_method :new

  private

  attr_reader :team, :academic_year, :programme_type

  def date = Date.current

  def team_location
    @team_location ||=
      TeamLocation.find_or_create_by!(
        team:,
        academic_year:,
        location: team.generic_clinic
      )
  end

  def existing_session
    Session.has_date(date).find_by(team_location:)
  end

  def new_session
    Session.create!(team_location:, dates: [date])
  end
end
