# frozen_string_literal: true

module HasSideEffects
  extend ActiveSupport::Concern

  included do
    extend ArrayEnum

    array_enum side_effects: {
                 aching: 0,
                 dizziness: 1,
                 drowsy: 2,
                 feeling_or_being_sick: 18,
                 feeling_sick: 3,
                 headache: 4,
                 high_temperature: 5,
                 irritable: 6,
                 loss_of_appetite: 8,
                 pain_in_arms: 9,
                 raised_temperature: 10,
                 rash: 11,
                 runny_blocked_nose: 12,
                 swelling: 13,
                 tiredness: 14,
                 unwell: 15,
                 swollen_glands: 16,
                 raised_blotchy_rash: 17
               }

    validates :side_effects, subset: side_effects.keys
  end
end
