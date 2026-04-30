# frozen_string_literal: true

# == Schema Information
#
# Table name: session_patients_exports
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  session_id :bigint           not null
#
# Foreign Keys
#
#  fk_rails_...  (session_id => sessions.id)
#
class SessionPatientsExport < ApplicationRecord
  belongs_to :session
  has_one :export, as: :exportable, touch: true

  delegate :location, to: :session

  def file_type = :xlsx

  def type_label = "Offline session"

  def name = "#{location.name} offline session"

  def filename
    "#{location.name} (#{location.urn_and_site}) - exported on #{Date.current.to_fs(:long)}.xlsx"
  end

  def generate_file
    Reports::OfflineExporter.from_session(session)
  end
end
