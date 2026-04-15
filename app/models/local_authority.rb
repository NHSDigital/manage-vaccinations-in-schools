# frozen_string_literal: true

# == Schema Information
#
# Table name: local_authorities
#
#  end_date      :date
#  gias_code     :integer
#  gov_uk_slug   :string
#  gss_code      :string
#  mhclg_code    :string           not null, primary key
#  nation        :string           not null
#  official_name :string           not null
#  region        :string
#  short_name    :string           not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
# Indexes
#
#  index_local_authorities_on_created_at             (created_at)
#  index_local_authorities_on_gias_code              (gias_code) UNIQUE
#  index_local_authorities_on_gss_code               (gss_code) UNIQUE
#  index_local_authorities_on_mhclg_code             (mhclg_code) UNIQUE
#  index_local_authorities_on_nation_and_short_name  (nation,short_name)
#  index_local_authorities_on_short_name             (short_name)
#

class LocalAuthority < ApplicationRecord
  self.primary_key = :mhclg_code

  validates :mhclg_code, uniqueness: true
  validates :gias_code, uniqueness: true, allow_nil: true
  validates :gss_code, uniqueness: true, allow_nil: true

  has_many :postcodes, foreign_key: :gss_code, primary_key: :gss_code

  enum :nation,
       {
         "England" => "england",
         "Northern Ireland" => "northern_ireland",
         "Scotland" => "scotland",
         "Wales" => "wales"
       },
       prefix: true

  enum :region,
       {
         "Yorkshire and The Humber" => "yorkshire_and_the_humber",
         "West Midlands" => "west_midlands",
         "East Midlands" => "east_midlands",
         "Northern Ireland" => "northern_ireland",
         "South East" => "south_east",
         "Wales" => "wales",
         "East of England" => "east_of_england",
         "Scotland" => "scotland",
         "North East" => "north_east",
         "North West" => "north_west",
         "South West" => "south_west",
         "London" => "london"
       },
       prefix: true,
       validate: {
         allow_nil: true
       }

  def self.from_my_society_import_row(data)
    new(
      mhclg_code: data["local-authority-code"],
      gss_code: data["gss-code"],
      gov_uk_slug: data["gov-uk-slug"],
      official_name: data["official-name"],
      short_name: data["nice-name"],
      nation: data["nation"],
      region: data["region"],
      end_date: data["end-date"]
    )
  end

  def self.for_postcode(postcode)
    joins(:postcodes).merge(Postcode.where(value: postcode)).first
  end
end
