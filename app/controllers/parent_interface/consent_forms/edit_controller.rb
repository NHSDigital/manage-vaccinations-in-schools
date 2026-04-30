# frozen_string_literal: true

module ParentInterface
  class ConsentForms::EditController < ConsentForms::BaseController
    include WizardControllerConcern

    before_action :validate_params, only: :update
    before_action :set_health_answer, if: :is_health_question_step?
    before_action :set_follow_up_changes_start_page, only: :show

    HOME_EDUCATED_SCHOOL_ID = "home-educated"

    def show
      case current_step
      when :response_doubles
        set_response_doubles
      when :response_flu
        set_response_flu
      when :response_hpv
        set_response_hpv
      when :injection_alternative
        set_injection_alternative
      when :without_gelatine
        set_without_gelatine
      end

      render_wizard
    end

    def update
      model = @consent_form

      model.wizard_step = current_step

      assign_attributes_for_current_step(model)

      if current_step == :parent
        if @consent_form.parental_responsibility == "no"
          redirect_to cannot_consent_responsibility_parent_interface_consent_form_path(
                        @consent_form
                      ) and return
        end

        if skip_to_confirm? && @consent_form.parent_phone_changed? &&
             @consent_form.parent_phone.present?
          jump_to("contact-method", skip_to_confirm: true)
        end
      elsif is_reason_for_refusal_step?
        @consent_form.reset_follow_up_requested
      elsif is_injection_alternative_step?
        @consent_form.update_injection_alternative
        @consent_form.seed_health_questions
      elsif is_without_gelatine_step?
        @consent_form.update_without_gelatine
        @consent_form.seed_health_questions
      elsif is_response_step?
        @consent_form.update_programme_responses
        @consent_form.seed_health_questions
      elsif ethnicity_flow_complete?
        handle_ethnicity_completion!(model)
        return
      end

      reload_steps

      skip_to_confirm_or_next_health_question

      render_wizard model, context:
    end

    private

    def assign_attributes_for_current_step(model)
      if is_health_question_step?
        @health_answer.assign_attributes(health_answer_params)
        model.health_question_number = @question_number
      elsif step == "school"
        school_id = update_params[:school_id]
        if school_id == HOME_EDUCATED_SCHOOL_ID
          model.school = nil
          model.education_setting = "home"
        else
          model.school_id = school_id
          model.education_setting = "school"
        end
      else
        model.assign_attributes(update_params)
      end
    end

    def handle_ethnicity_completion!(model)
      model.save!

      # This job will have already been scheduled in the
      # background after recording the consent. If the
      # parent decides to answer "Yes" or "No" (they might not)
      # to the ethnicity questions, the job will make sure the
      # ethnicity information is copied to the matched patient.
      ProcessConsentFormSidekiqJob.perform_async(model.id)

      redirect_to submitted_parent_interface_consent_form_path(model)
    end

    def context
      if @consent_form.ethnicity_steps.include?(current_step)
        :ethnicity_update
      else
        :update
      end
    end

    def ethnicity_flow_complete?
      if current_step == :ethnicity && @consent_form.ethnicity_question == "no"
        return true
      end

      if current_step == :ethnic_background &&
           @consent_form.ethnic_background.present?
        return true
      end

      false
    end

    def finish_wizard_path
      confirm_parent_interface_consent_form_path(@consent_form)
    end

    def update_params
      permitted_attributes = {
        address: %i[
          address_line_1
          address_line_2
          address_town
          address_postcode
        ],
        confirm_school: %i[school_confirmed],
        contact_method: %i[
          parent_contact_method_type
          parent_contact_method_other_details
        ],
        date_of_birth: %i[
          date_of_birth(3i)
          date_of_birth(2i)
          date_of_birth(1i)
        ],
        education_setting: %i[education_setting],
        ethnicity: %i[ethnicity_question],
        ethnic_group: %i[ethnic_group],
        ethnic_background: %i[ethnic_background ethnic_background_other],
        injection_alternative: %i[injection_alternative],
        name: %i[
          given_name
          family_name
          use_preferred_name
          preferred_given_name
          preferred_family_name
        ],
        parent: %i[
          parent_email
          parent_full_name
          parent_phone
          parent_phone_receive_updates
          parent_relationship_other_name
          parent_relationship_type
          parental_responsibility
        ],
        follow_up_discussion: %i[follow_up_requested],
        reason_for_refusal: %i[reason_for_refusal],
        reason_for_refusal_notes: %i[reason_for_refusal_notes],
        response_doubles: %i[response chosen_programme],
        response_flu: %i[response],
        response_hpv: %i[response],
        response_mmr: %i[response],
        school: %i[school_id],
        without_gelatine: %i[without_gelatine]
      }.fetch(current_step)

      params.fetch(:consent_form, {}).permit(permitted_attributes)
    end

    def health_answer_params
      params.fetch(:health_answer, {}).permit(%i[response notes])
    end

    def set_steps
      self.steps =
        if @consent_form.recorded?
          @consent_form.ethnicity_steps
        else
          @consent_form.wizard_steps
        end
    end

    def set_health_answer
      @question_number = params.fetch(:question_number, "0").to_i

      @health_answer = @consent_form.health_answers[@question_number]
    end

    def set_response_doubles
      if @consent_form.response_given? && @consent_form.response_refused?
        @consent_form.response = "given_one"
        @consent_form.chosen_programme =
          @consent_form.given_consent_form_programmes.first.programme_type
      elsif @consent_form.response_given?
        @consent_form.response = "given"
      elsif @consent_form.response_refused?
        @consent_form.response = "refused"
      end
    end

    def set_response_flu
      if @consent_form.response_given?
        method =
          @consent_form
            .given_consent_form_programmes
            .first
            .vaccine_methods
            .first
        @consent_form.response = "given_#{method}"
      elsif @consent_form.response_refused?
        @consent_form.response = "refused"
      end
    end

    def set_response_hpv
      if @consent_form.response_given?
        @consent_form.response = "given"
      elsif @consent_form.response_refused?
        @consent_form.response = "refused"
      end
    end

    def set_injection_alternative
      if @consent_form.consent_form_programmes.any?(
           &:vaccine_method_injection_and_nasal?
         )
        @consent_form.injection_alternative = "true"
      end
    end

    def set_without_gelatine
      if @consent_form.consent_form_programmes.any?(&:without_gelatine?)
        @consent_form.without_gelatine = "true"
      end
    end

    def validate_params
      case current_step
      when :date_of_birth
        validator =
          DateParamsValidator.new(
            field_name: :date_of_birth,
            object: @consent_form,
            params: update_params
          )

        unless validator.date_params_valid?
          @consent_form.date_of_birth = validator.date_params_as_struct
          render_wizard nil, status: :unprocessable_content
        end
      end
    end

    def is_response_step? = step.start_with?("response-")

    def is_injection_alternative_step? = step == "injection-alternative"

    def is_without_gelatine_step? = step == "without-gelatine"

    def is_health_question_step? = step == "health-question"

    def is_reason_for_refusal_step? = step == "reason-for-refusal"

    def current_health_answer
      index = step.split("-").last.to_i - 1
      @consent_form.health_answers[index]
    end

    def skip_to_confirm?
      request.referer&.include?("skip_to_confirm") ||
        params.key?(:skip_to_confirm) ||
        session.key?(:follow_up_changes_start_page)
    end

    def next_health_question
      @next_health_question ||= @health_answer.next_health_answer_index
    end

    def next_health_answer_missing_response?
      if next_health_question
        @consent_form.health_answers[next_health_question].response.blank?
      else
        false
      end
    end

    def skip_to_confirm_or_next_health_question
      if skip_to_confirm?
        return if @skip_to.present? # already going somewhere else

        if is_health_question_step? && next_health_answer_missing_response?
          jump_to "health-question", question_number: next_health_question
        else
          jump_to Wicked::FINISH_STEP
        end
      elsif is_health_question_step? && next_health_question
        jump_to "health-question", question_number: next_health_question
      end
    end

    def set_follow_up_changes_start_page
      if params[:skip_to_confirm] && is_health_question_step?
        session[:follow_up_changes_start_page] = @question_number
      end
    end
  end
end
