# frozen_string_literal: true

class ParentsController < ApplicationController
  before_action :set_patient
  before_action :set_parent, except: %i[new create]
  before_action :set_parent_relationship, except: %i[new create]

  def set_parent_relationship
    @parent_relationship =
      authorize @patient
                  .parent_relationships
                  .includes(:parent)
                  .find_by!(parent_id: params[:id])
  end

  def new
    @parent = authorize Parent.new(patient: @patient)
  end

  def create
    authorize @parent_ = @patient.parents.build(parent_params)

    if @parent.save
      redirect_to edit_patient_path(@patient)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @parent.contact_method_type = "any" if @parent.contact_method_type.nil?
  end

  def update
    if @parent.update(parent_params) &&
         @parent_relationship.update(parent_relationship_params)
      redirect_to edit_patient_path(@patient)
    else
      render :edit, status: :unprocessable_content
    end
  end

  def confirm_destroy = render :destroy

  def destroy
    @parent.destroy!

    redirect_to edit_patient_path(@patient),
                flash: {
                  success: "Parent removed"
                }
  end

  private

  def set_patient
    @patient = policy_scope(Patient).find(params[:patient_id])
  end

  def set_parent
    @parent = authorize(@patient.parents.find(params[:id]))
  end

  def parent_params
    params.expect(
      parent: %i[
        id
        type
        other_name
        full_name
        email
        phone
        phone_receive_updates
        contact_method_other_details
        contact_method_type
      ]
    )
  end

  def parent_relationship_params
    params.expect(parent: %i[id type other_name])
  end
end
