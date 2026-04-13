# frozen_string_literal: true

module Refusable
  extend ActiveSupport::Concern

  include Notable

  REASON_FOR_REFUSAL_REQUIRES_NOTES = %w[
    already_vaccinated
    medical_reasons
    other
    will_be_vaccinated_elsewhere
  ].freeze

  included do
    enum :reason_for_refusal,
         {
           contains_gelatine: 0,
           already_vaccinated: 1,
           will_be_vaccinated_elsewhere: 2,
           medical_reasons: 3,
           personal_choice: 4,
           other: 5,
           do_not_want_vaccination_at_school: 6
         },
         prefix: true,
         validate: {
           if: :requires_reason_for_refusal?
         }

    validates :reason_for_refusal,
              absence: true,
              unless: :can_have_reason_for_refusal?
  end

  def hard_refusal? = response_refused? && !follow_up_requested?

  def refusal_with_follow_up? = response_refused? && follow_up_requested?

  def requires_reason_for_refusal?
    response_refused?
  end

  def reason_for_refusal_requires_notes?
    reason_for_refusal.in?(REASON_FOR_REFUSAL_REQUIRES_NOTES)
  end

  def requires_notes?
    requires_reason_for_refusal? && reason_for_refusal_requires_notes?
  end
end
