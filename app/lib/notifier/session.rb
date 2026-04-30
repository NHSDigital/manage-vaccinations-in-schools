# frozen_string_literal: true

class Notifier::Session
  def initialize(session)
    @session = session
  end

  def send_cancellation(sent_by:)
    session
      .patients
      .includes(:parents, consents: :parent)
      .find_each do |patient|
        parents_for(patient).each do |parent|
          EmailDeliveryJob.perform_later(
            :session_clinic_cancelled,
            parent:,
            patient:,
            session:,
            sent_by:
          )
        end
      end
  end

  private

  attr_reader :session

  def parents_for(patient)
    session.programmes.flat_map do |programme|
      latest_consents =
        ConsentGrouper.call(
          patient.consents,
          programme_type: programme.type,
          academic_year: session.academic_year
        )

      if latest_consents.any?(&:via_self_consent?)
        patient.parents.select(&:contactable?)
      else
        latest_consents.filter_map do |consent|
          parent = consent.parent
          parent if consent.response_given? && parent&.contactable?
        end
      end
    end
  end
end
