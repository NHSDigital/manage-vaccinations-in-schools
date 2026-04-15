# frozen_string_literal: true

class ParentRelationshipsController < ApplicationController
  before_action :set_patient
  before_action :set_parent_relationship, except: %i[new create]
  before_action :set_parent, except: %i[new create]

  def new
    @parent_relationship = authorize ParentRelationship.new(patient: @patient)
    @parent_relationship.build_parent
  end

  def create
    authorize @parent_relationship =
                @patient.parent_relationships.build(parent_relationship_params)

    if @parent_relationship.save
      PatientStatusUpdater.call(patient: @patient)
      redirect_to edit_patient_path(@patient)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @parent.contact_method_type = "any" if @parent.contact_method_type.nil?
  end

  def update
    if @parent_relationship.update(parent_relationship_params)
      PatientStatusUpdater.call(patient: @patient)
      redirect_to edit_patient_path(@patient)
    else
      render :edit, status: :unprocessable_content
    end
  end

  def confirm_destroy = render :destroy

  def destroy
    @parent_relationship.destroy!

    PatientStatusUpdater.call(patient: @patient)
    redirect_to edit_patient_path(@patient),
                flash: {
                  success: "Parent relationship removed"
                }
  end

  private

  def set_patient
    @patient = policy_scope(Patient).find(params[:patient_id])
  end

  def set_parent_relationship
    @parent_relationship =
      authorize @patient
                  .parent_relationships
                  .includes(:parent)
                  .find_by!(parent_id: params[:id])
  end

  def set_parent
    @parent = @parent_relationship.parent
  end

  def parent_relationship_params
    params.expect(
      parent_relationship: [
        :type,
        :other_name,
        {
          parent_attributes: %i[
            id
            full_name
            email
            phone
            phone_receive_updates
            contact_method_other_details
            contact_method_type
          ]
        }
      ]
    )
  end
end
