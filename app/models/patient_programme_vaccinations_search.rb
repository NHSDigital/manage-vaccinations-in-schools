# frozen_string_literal: true

# == Schema Information
#
# Table name: patient_programme_vaccinations_searches
#
#  id               :bigint           not null, primary key
#  last_searched_at :datetime         not null
#  programme_type   :enum             not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  patient_id       :bigint           not null
#
# Indexes
#
#  idx_on_last_searched_at_96aaa59442                           (last_searched_at)
#  idx_on_programme_type_0d0cfaeb86                             (programme_type)
#  index_patient_programme_vaccinations_searches_on_patient_id  (patient_id)
#
# Foreign Keys
#
#  fk_rails_...  (patient_id => patients.id) ON DELETE => cascade
#
class PatientProgrammeVaccinationsSearch < ApplicationRecord
  include BelongsToProgramme

  belongs_to :patient
end
