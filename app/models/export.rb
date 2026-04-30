# frozen_string_literal: true

# == Schema Information
#
# Table name: exports
#
#  id              :bigint           not null, primary key
#  exportable_type :string           not null
#  file_data       :binary
#  file_type       :string           not null
#  filename        :string           not null
#  status          :string           default("pending"), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  exportable_id   :bigint           not null
#  team_id         :bigint           not null
#  user_id         :bigint           not null
#
# Indexes
#
#  index_exports_on_created_at  (created_at)
#  index_exports_on_exportable  (exportable_type,exportable_id)
#  index_exports_on_status      (status)
#  index_exports_on_team_id     (team_id)
#
# Foreign Keys
#
#  fk_rails_...  (team_id => teams.id)
#  fk_rails_...  (user_id => users.id)
#
class Export < ApplicationRecord
  delegated_type :exportable,
                 types: %w[
                   LocationPatientsExport
                   SessionPatientsExport
                   VaccinationRecordsExport
                   SchoolMovesExport
                 ],
                 dependent: :destroy

  belongs_to :team
  belongs_to :user

  enum :status,
       {
         pending: "pending",
         ready: "ready",
         failed: "failed",
         expired: "expired"
       }
  enum :file_type, { csv: "csv", xlsx: "xlsx" }

  CONTENT_TYPES = {
    "csv" => "text/csv",
    "xlsx" =>
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
  }.freeze

  def content_type = CONTENT_TYPES.fetch(file_type)

  def self.from_exportable(exportable, user:, team:)
    new(
      exportable:,
      user:,
      team:,
      file_type: exportable.file_type,
      filename: exportable.filename
    )
  end

  delegate :type_label, :name, to: :exportable
end
