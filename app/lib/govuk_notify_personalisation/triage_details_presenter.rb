# frozen_string_literal: true

class GovukNotifyPersonalisation
  class TriageDetailsPresenter
    def initialize(personalisation)
      @personalisation = personalisation
    end

    attr_reader :personalisation

    delegate :patient, :session, :short_patient_name, to: :personalisation

    def delay_vaccination_review_context
      return if patient.nil? || session.nil?

      latest_delayed_triage =
        patient.latest_delayed_triage(programme_types: session.programme_types)

      return if latest_delayed_triage.nil?

      session_date = session.next_date(include_today: true)
      triage_date = latest_delayed_triage.created_at.to_date

      if session_date && triage_date == session_date
        "assessed #{short_patient_name} in the vaccination session"
      else
        "reviewed the answers you gave to the health questions about #{short_patient_name}"
      end
    end
  end
end
