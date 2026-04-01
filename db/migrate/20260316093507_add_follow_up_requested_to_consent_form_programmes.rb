# frozen_string_literal: true

class AddFollowUpRequestedToConsentFormProgrammes < ActiveRecord::Migration[8.1]
  def change
    add_column :consent_form_programmes, :follow_up_requested, :boolean
  end
end
