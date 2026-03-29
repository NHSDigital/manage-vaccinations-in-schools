# frozen_string_literal: true

class UpdateRevaxisSideEffects < ActiveRecord::Migration[8.0]
  SNOMED_CODE = "7374511000001107" # Revaxis

  def up
    vaccine = Vaccine.find_by!(snomed_product_code: SNOMED_CODE)
    vaccine.update!(
      side_effects:
        (vaccine.side_effects - %w[drowsy feeling_sick irritable loss_of_appetite unwell]) |
          %w[dizziness feeling_or_being_sick]
    )
  end

  def down
    vaccine = Vaccine.find_by!(snomed_product_code: SNOMED_CODE)
    vaccine.update!(
      side_effects:
        (vaccine.side_effects - %w[dizziness feeling_or_being_sick]) |
          %w[drowsy feeling_sick irritable loss_of_appetite unwell]
    )
  end
end
