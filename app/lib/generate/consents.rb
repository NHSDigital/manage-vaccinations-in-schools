# frozen_string_literal: true

class Generate::Consents
  def initialize(
    team:,
    programme: nil,
    session: nil,
    refused: 0,
    given: 0,
    given_needs_triage: 0
  )
    validate_programme_and_session(programme, session) if programme

    @team = team
    @programme = programme || team.programmes.sample
    @session = session
    @refused = refused
    @given = given
    @given_needs_triage = given_needs_triage
    @updated_patients = []
  end

  def call
    create_consents(:refused, @refused)
    create_consents(:given, @given)
    create_consents(:needing_triage, @given_needs_triage)

    PatientStatusUpdater.call(patient: @updated_patients)
  end

  def self.call(...) = new(...).call

  private

  attr_reader :team, :programme

  def patients
    @patients ||=
      begin
        sessions =
          if @session
            [@session]
          else
            team
              .sessions
              .eager_load(
                :location,
                :session_programme_year_groups,
                :team_location
              )
              .merge(Location.gias_school)
              .has_all_programmes_of([programme])
          end

        sessions.flat_map do |session|
          session
            .patients
            .includes(:parents, :school, :consents, consents: :parent)
            .select { it.consents.empty? && it.parents.any? }
        end
      end
  end

  def random_patients(count)
    @patients_randomised ||= patients.shuffle
    @patients_randomised
      .shift(count)
      .tap do
        if it.size < count
          raise "Only #{it.size} patients without consent in #{programme.type} programme"
        end
      end
  end

  def session_for(patient)
    @session ||
      patient
        .sessions
        .joins(
          "INNER JOIN locations ON locations.id = team_locations.location_id"
        )
        .merge(Location.gias_school)
        .has_all_programmes_of([programme])
        .sample
  end

  def create_consents(response, count)
    available_patient_sessions =
      random_patients(count).map { [it, session_for(it)] }

    if response == :needing_triage
      response = :given
      traits = %i[given needing_triage]
    else
      traits = [response]
    end

    consent_forms =
      available_patient_sessions.map do |patient, session|
        school =
          session.location.gias_school? ? session.location : patient.school

        @updated_patients << patient

        FactoryBot.build(
          :consent_form,
          team:,
          programmes: [programme],
          session:,
          school:,
          response:,
          consents: [
            FactoryBot.build(:consent, *traits, patient:, programme:, team:)
          ]
        )
      end

    ConsentForm.import!(consent_forms, recursive: true)
  end

  def validate_programme_and_session(programme, session)
    if session
      if session.programmes.exclude?(programme)
        raise "Session does not support programme #{programme.type}"
      end
    elsif Session
          .has_any_programmes_of([programme])
          .none? { it.location.gias_school? }
      raise "Programme #{programme.type} does not have a school session"
    end
  end
end
