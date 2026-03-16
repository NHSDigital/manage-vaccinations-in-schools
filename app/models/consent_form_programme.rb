# frozen_string_literal: true

# == Schema Information
#
# Table name: consent_form_programmes
#
#  id                  :bigint           not null, primary key
#  disease_types       :enum             is an Array
#  follow_up_requested :boolean
#  notes               :text             default(""), not null
#  programme_type      :enum             not null
#  reason_for_refusal  :integer
#  response            :integer
#  vaccine_methods     :integer          default([]), not null, is an Array
#  without_gelatine    :boolean
#  consent_form_id     :bigint           not null
#
# Indexes
#
#  idx_on_programme_type_consent_form_id_805eb5d685  (programme_type,consent_form_id) UNIQUE
#  index_consent_form_programmes_on_consent_form_id  (consent_form_id)
#
# Foreign Keys
#
#  fk_rails_...  (consent_form_id => consent_forms.id) ON DELETE => cascade
#
class ConsentFormProgramme < ApplicationRecord
  include BelongsToProgramme
  include HasVaccineMethods
  include Refusable

  belongs_to :consent_form

  scope :ordered, -> { order(:programme_type) }

  enum :response, { given: 0, refused: 1 }, prefix: true

  delegate :flu?, :hpv?, :menacwy?, :mmr?, :td_ipv?, to: :programme

  def vaccines
    VaccineCriteria.from_consentable(self).apply(
      Vaccine.active.where(programme_type:, disease_types:)
    )
  end

  def human_enum_name(attribute)
    Consent.human_enum_name(attribute, send(attribute))
  end

  private

  def requires_reason_for_refusal? = false

  def can_have_reason_for_refusal? = true
end
