# frozen_string_literal: true

class PatientArchiveForm
  include PatientMergeFormConcern

  attr_accessor :current_user, :patient

  attribute :other_details, :string
  attribute :type, :string

  validates :nhs_number, nhs_number: true, if: :duplicate?

  validate :nhs_number_is_different, if: :duplicate?

  validates :other_details,
            presence: true,
            length: {
              maximum: 300
            },
            if: :other?

  validates :type,
            inclusion: {
              in: %w[duplicate imported_in_error moved_out_of_area other]
            }

  def save
    return false unless valid?

    if duplicate?
      super
    else
      PatientArchiver.call(
        patient:,
        team:,
        type:,
        other_details:,
        user: current_user
      )
    end
  end

  def duplicate? = type == "duplicate"

  def other? = type == "other"

  private

  def team = current_user.selected_team

  def nhs_number_is_different
    return if nhs_number.blank?
    return if nhs_number != patient.nhs_number

    errors.add(
      :nhs_number,
      "No other child record has this NHS number. Enter the NHS number of the duplicate record."
    )
  end
end
