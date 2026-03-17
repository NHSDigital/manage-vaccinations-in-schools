# frozen_string_literal: true

module PatientMatcher
  def self.from_relation(
    relation,
    nhs_number:,
    given_name:,
    family_name:,
    date_of_birth:,
    address_postcode:,
    include_3_out_of_4_matches: true
  )
    nhs_number = normalise_nhs_number(nhs_number)
    address_postcode = normalise_postcode(address_postcode)

    if nhs_number.present? && (patient = relation.find_by(nhs_number:)).present?
      return [patient]
    end

    scope =
      relation.where(
        "lower(given_name) = lower(?) AND lower(family_name) = lower(?)",
        given_name,
        family_name
      ).where(date_of_birth:)

    if address_postcode.present?
      scope =
        if include_3_out_of_4_matches
          scope
            .or(
              relation.where(
                "lower(given_name) = lower(?) AND lower(family_name) = lower(?)",
                given_name,
                family_name
              ).where(address_postcode:)
            )
            .or(
              relation.where("lower(given_name) = lower(?)", given_name).where(
                date_of_birth:,
                address_postcode:
              )
            )
            .or(
              relation.where(
                "lower(family_name) = lower(?)",
                family_name
              ).where(date_of_birth:, address_postcode:)
            )
        else
          scope.where(address_postcode:)
        end
    end

    results =
      if nhs_number.blank?
        scope.to_a
      else
        # This prevents us from finding a patient that happens to have at least
        # three of the other fields the same, but with a different NHS number,
        # and therefore cannot be a match.
        relation.where(nhs_number: nil).merge(scope).to_a
      end

    narrow_to_single_exact_match_if_possible(
      results,
      given_name:,
      family_name:,
      date_of_birth:,
      address_postcode:
    )
  end

  def self.from_enumerable(
    candidates,
    nhs_number:,
    given_name:,
    family_name:,
    date_of_birth:,
    address_postcode:,
    include_3_out_of_4_matches: true
  )
    nhs_number = normalise_nhs_number(nhs_number)
    address_postcode = normalise_postcode(address_postcode)

    if nhs_number.present?
      matched =
        candidates.find { normalise_nhs_number(it.nhs_number) == nhs_number }

      return [matched] if matched.present?
    end

    given_name_downcase = given_name.downcase
    family_name_downcase = family_name.downcase

    results =
      candidates.select do
        patient_nhs_number = normalise_nhs_number(it.nhs_number)
        next false if nhs_number.present? && patient_nhs_number.present?

        given_name_matches = it.given_name.to_s.downcase == given_name_downcase
        family_name_matches =
          it.family_name.to_s.downcase == family_name_downcase
        date_of_birth_matches = it.date_of_birth == date_of_birth

        if address_postcode.present?
          postcode_matches =
            normalise_postcode(it.address_postcode) == address_postcode

          if include_3_out_of_4_matches
            (
              given_name_matches && family_name_matches && date_of_birth_matches
            ) ||
              (given_name_matches && family_name_matches && postcode_matches) ||
              (
                given_name_matches && date_of_birth_matches && postcode_matches
              ) ||
              (family_name_matches && date_of_birth_matches && postcode_matches)
          else
            given_name_matches && family_name_matches &&
              date_of_birth_matches && postcode_matches
          end
        else
          given_name_matches && family_name_matches && date_of_birth_matches
        end
      end

    narrow_to_single_exact_match_if_possible(
      results,
      given_name:,
      family_name:,
      date_of_birth:,
      address_postcode:
    )
  end

  def self.narrow_to_single_exact_match_if_possible(
    results,
    given_name:,
    family_name:,
    date_of_birth:,
    address_postcode:
  )
    return results if address_postcode.blank?

    exact_results =
      results.select do
        normalise_postcode(it.address_postcode) == address_postcode &&
          it.given_name.to_s.casecmp?(given_name) &&
          it.family_name.to_s.casecmp?(family_name) &&
          it.date_of_birth == date_of_birth
      end

    exact_results.length == 1 ? exact_results : results
  end

  def self.normalise_nhs_number(nhs_number)
    nhs_number&.normalise_whitespace&.gsub(/\s/, "")
  end

  def self.normalise_postcode(address_postcode)
    return if address_postcode.blank?

    parsed_postcode = UKPostcode.parse(address_postcode)
    parsed_postcode.valid? ? parsed_postcode.to_s : nil
  end

  private_class_method :narrow_to_single_exact_match_if_possible,
                       :normalise_nhs_number,
                       :normalise_postcode
end
