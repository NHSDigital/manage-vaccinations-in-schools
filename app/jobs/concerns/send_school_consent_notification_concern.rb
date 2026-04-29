# frozen_string_literal: true

module SendSchoolConsentNotificationConcern
  extend ActiveSupport::Concern

  def patient_programmes_eligible_for_notification(session:)
    return unless session.school? && session.can_receive_consent?

    session
      .patient_locations
      .includes(patient: %i[consent_notifications programme_statuses])
      .find_each do |patient_location|
        patient = patient_location.patient
        next unless patient.send_notifications?(team: session.team)

        ProgrammeGrouper
          .call(session.programmes_for(patient:))
          .each_value do |programmes|
            programmes_that_need_response =
              get_programmes_that_need_consent(patient:, session:, programmes:)
            next if programmes_that_need_response.empty?

            yield patient, programmes_that_need_response
          end
      end
  end

  def get_programmes_that_need_consent(patient:, session:, programmes:)
    academic_year = session.academic_year

    programmes.select do |programme|
      patient.programme_status(programme, academic_year:).needs_consent?
    end
  end
end
