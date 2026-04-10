# frozen_string_literal: true

class UpdateFluInjectionSideEffects < ActiveRecord::Migration[8.0]
  SNOMED_CODES = %w[
    43207411000001105
    45175511000001104
    45354911000001100
  ].freeze # Cell-based Trivalent, Vaxigrip, Viatris

  def up
    SNOMED_CODES.each do |code|
      vaccine = Vaccine.find_by!(snomed_product_code: code)
      vaccine.update!(
        side_effects:
          (vaccine.side_effects -
            %w[headache high_temperature feeling_sick irritable drowsy
               loss_of_appetite unwell]) |
            %w[aching raised_temperature]
      )
    end
  end

  def down
    SNOMED_CODES.each do |code|
      vaccine = Vaccine.find_by!(snomed_product_code: code)
      vaccine.update!(
        side_effects:
          (vaccine.side_effects - %w[aching raised_temperature]) |
            %w[headache high_temperature feeling_sick irritable drowsy
               loss_of_appetite unwell]
      )
    end
  end
end
