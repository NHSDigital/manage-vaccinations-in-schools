# frozen_string_literal: true

# == Schema Information
#
# Table name: local_authority_postcodes
#
#  gss_code   :string           not null
#  value      :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_local_authority_postcodes_on_gss_code  (gss_code)
#  index_local_authority_postcodes_on_value     (value) UNIQUE
#

class LocalAuthority::Postcode < ApplicationRecord
  belongs_to :local_authority, foreign_key: :gss_code, primary_key: :gss_code

  normalizes :value,
             with: ->(given_value) do
               if given_value.nil?
                 nil
               else
                 UKPostcode.parse(given_value.gsub(/[^A-Z0-9\s]+/i, "")).to_s
               end
             end
end
