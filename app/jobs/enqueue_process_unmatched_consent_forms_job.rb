# frozen_string_literal: true

class EnqueueProcessUnmatchedConsentFormsJob < ApplicationJobActiveJob
  include SingleConcurrencyConcern

  queue_as :consents

  def perform
    ConsentForm.unmatched.find_each do |consent_form|
      ProcessConsentFormJob.perform_later(consent_form.id)
    end
  end
end
