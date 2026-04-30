# frozen_string_literal: true

# == Schema Information
#
# Table name: school_moves_exports
#
#  id         :bigint           not null, primary key
#  date_from  :date
#  date_to    :date
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
FactoryBot.define do
  factory :school_moves_export do
  end
end
