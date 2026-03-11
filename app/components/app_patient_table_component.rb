# frozen_string_literal: true

class AppPatientTableComponent < ViewComponent::Base
  def initialize(patients, current_user:, pagy:, anchor: nil)
    @patients = patients
    @current_user = current_user
    @pagy = pagy
    @anchor = anchor
  end

  private

  attr_reader :patients, :current_user, :current_team, :pagy, :anchor

  delegate :govuk_table, to: :helpers

  def can_link_to?(record) = allowed_ids.include?(record.id)

  def unlinkable_patient_hint_text(patient)
    if patient.deceased?
      "Child is deceased"
    elsif patient.teams.any? && !patient.teams.include?(current_team)
      "Child is in a different SAIS team"
    elsif patient.sessions.empty?
      "Child is not in any sessions"
    else
      "Child has moved out of the area"
    end
  end

  def allowed_ids
    @allowed_ids ||= PatientPolicy::Scope.new(current_user, Patient).resolve.ids
  end
end
