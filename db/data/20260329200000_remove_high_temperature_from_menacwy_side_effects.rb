# frozen_string_literal: true

class RemoveHighTemperatureFromMenacwySideEffects < ActiveRecord::Migration[8.0]
  SNOMED_CODES = %w[
    39779611000001104
    17188711000001105
    20517811000001104
  ].freeze # MenQuadfi, Menveo, Nimenrix

  def up
    SNOMED_CODES.each do |code|
      vaccine = Vaccine.find_by!(snomed_product_code: code)
      vaccine.update!(side_effects: vaccine.side_effects - %w[high_temperature])
    end
  end

  def down
    SNOMED_CODES.each do |code|
      vaccine = Vaccine.find_by!(snomed_product_code: code)
      vaccine.update!(side_effects: vaccine.side_effects | %w[high_temperature])
    end
  end
end
