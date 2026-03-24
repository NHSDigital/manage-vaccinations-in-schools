# frozen_string_literal: true

module Schoolable
  extend ActiveSupport::Concern

  included do
    belongs_to :school, class_name: "Location", optional: true

    validates :school,
              presence: {
                if: -> { home_educated.nil? }
              },
              absence: {
                unless: -> { home_educated.nil? }
              }

    validates :home_educated, inclusion: { in: :valid_home_educated_values }

    validate :school_is_correct_type
  end

  private

  def valid_home_educated_values
    school.nil? ? [true, false] : [nil]
  end

  def school_is_correct_type
    location = school
    if location && !(location.school? || location.generic_school?)
      errors.add(:school, "must be a school location type")
    end
  end
end
