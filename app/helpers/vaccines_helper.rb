# frozen_string_literal: true

module VaccinesHelper
  def vaccine_heading(vaccine)
    "#{vaccine.brand} (#{vaccine.programme.name})"
  end

  def vaccine_method(vaccine)
    return unless vaccine

    vaccine.human_enum_name(:method)&.downcase
  end

  def vaccine_side_effects_list(vaccine)
    return if vaccine.nil?

    vaccine
      .side_effects
      .map { Vaccine.human_enum_name(:side_effect, it) }
      .sort
      .uniq
      .map { "- #{it}" }
      .join("\n")
  end
end
