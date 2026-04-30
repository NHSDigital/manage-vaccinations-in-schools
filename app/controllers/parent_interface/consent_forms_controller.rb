# frozen_string_literal: true

module ParentInterface
  class ConsentFormsController < ConsentForms::BaseController
    with_options only: %i[start create deadline_passed] do
      skip_before_action :set_consent_form
      skip_before_action :authenticate_consent_form_user!
    end

    skip_before_action :check_if_past_deadline!, only: :deadline_passed

    before_action :clear_session_edit_variables, only: :confirm

    def start
    end

    def deadline_passed
    end

    def create
      consent_form =
        ActiveRecord::Base.transaction do
          consent_form =
            ConsentForm.create!(
              original_session: @session,
              team_location: @team_location
            )

          @programmes.each do |programme|
            consent_form.consent_form_programmes.create!(programme:)
          end

          consent_form
        end

      session[:consent_form_id] = consent_form.id

      redirect_to parent_interface_consent_form_edit_path(consent_form, :name)
    end

    def cannot_consent_responsibility
    end

    def confirm
      previous_step = t(@consent_form.wizard_steps.last, scope: :wicked)

      @back_link_path =
        if previous_step == "health-question"
          question_number = @consent_form.each_health_answer.to_a.last&.id
          parent_interface_consent_form_edit_path(
            @consent_form,
            previous_step,
            question_number:
          )
        else
          parent_interface_consent_form_edit_path(@consent_form, previous_step)
        end
    end

    def record
      @consent_form.update!(recorded_at: Time.zone.now)

      TeamCachedCounts.new(@team).reset_unmatched_consent_responses!

      # We enqueue ProcessConsentFormJob here as a backup: ethnicity
      # is optional and the parent may abandon the journey before
      # answering. Running the job ensures the consent form is still
      # processed and, if ethnicity was provided, it gets copied
      # onto the matched patient.
      ProcessConsentFormJob.perform_async(@consent_form.id)

      if Flipper.enabled?(:ethnicity_capture)
        redirect_to parent_interface_consent_form_edit_path(
                      @consent_form,
                      "ethnicity"
                    )
      else
        redirect_to submitted_parent_interface_consent_form_path(@consent_form)
      end
    end

    def submitted
      session.delete(:consent_form_id)
    end

    private

    def clear_session_edit_variables
      session.delete(:follow_up_changes_start_page)
    end
  end
end
