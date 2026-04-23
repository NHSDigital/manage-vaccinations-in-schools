# frozen_string_literal: true

class NHSNumberValidator < ActiveModel::EachValidator
  DIGITS = %w[0 1 2 3 4 5 6 7 8 9].freeze

  def validate_each(record, attribute, value)
    if value.blank?
      record.errors.add(attribute, :blank) unless options[:allow_blank]
    elsif value.nil?
      record.errors.add(attribute, :blank) unless options[:allow_nil]
    elsif value.length != 10
      record.errors.add(
        attribute,
        options[:message] || :wrong_length,
        count: 10
      )
    else
      # https://archive.datadictionary.nhs.uk/DD%20Release%20May%202024/attributes/nhs_number.html
      digits = value.chars.map { DIGITS.include?(it) ? it.to_i : nil }

      if digits.any?(&:nil?)
        record.errors.add(attribute, options[:message] || :invalid)
        return
      end

      digits_multiplied_by_weighting_factor =
        digits
          .slice(0, 9)
          .each_with_index
          .map { |digit, index| (11 - (index + 1)) * digit }

      digits_sum_remainder = digits_multiplied_by_weighting_factor.sum % 11

      check_digit = (digits_sum_remainder.zero? ? 0 : 11 - digits_sum_remainder)

      if check_digit > 9 || digits.last != check_digit
        record.errors.add(attribute, options[:message] || :invalid)
      end
    end
  end
end
