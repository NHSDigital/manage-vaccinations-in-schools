# frozen_string_literal: true

module ProgrammesHelper
  def programme_name_for_parents(programme)
    nhs_name = programme.name_on_nhs_uk
    if nhs_name
      "#{programme.name_in_sentence} (#{nhs_name})"
    else
      programme.name_in_sentence
    end
  end
end
