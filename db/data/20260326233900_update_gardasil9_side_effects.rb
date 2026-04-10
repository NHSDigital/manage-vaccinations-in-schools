# frozen_string_literal: true

class UpdateGardasil9SideEffects < ActiveRecord::Migration[8.0]
  def up
    vaccine = Vaccine.find_by!(snomed_product_code: "33493111000001108")
    vaccine.update!(
      side_effects:
        (vaccine.side_effects - %w[irritable drowsy loss_of_appetite unwell]) |
          %w[dizziness tiredness]
    )
  end

  def down
    vaccine = Vaccine.find_by!(snomed_product_code: "33493111000001108")
    vaccine.update!(
      side_effects:
        (vaccine.side_effects - %w[dizziness tiredness]) |
          %w[irritable drowsy loss_of_appetite unwell]
    )
  end
end
