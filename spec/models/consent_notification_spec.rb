# frozen_string_literal: true

# == Schema Information
#
# Table name: consent_notifications
#
#  id               :bigint           not null, primary key
#  programme_types  :enum             not null, is an Array
#  sent_at          :datetime         not null
#  type             :integer          not null
#  patient_id       :bigint           not null
#  sent_by_user_id  :bigint
#  session_id       :bigint
#  team_location_id :bigint           not null
#
# Indexes
#
#  index_consent_notifications_on_patient_id        (patient_id)
#  index_consent_notifications_on_programme_types   (programme_types) USING gin
#  index_consent_notifications_on_sent_by_user_id   (sent_by_user_id)
#  index_consent_notifications_on_session_id        (session_id)
#  index_consent_notifications_on_team_location_id  (team_location_id)
#
# Foreign Keys
#
#  fk_rails_...  (patient_id => patients.id)
#  fk_rails_...  (sent_by_user_id => users.id)
#  fk_rails_...  (session_id => sessions.id)
#
describe ConsentNotification do
  describe "associations" do
    it { should belong_to(:patient) }
    it { should belong_to(:session).optional(true) }
    it { should belong_to(:team_location).optional(true) }
  end
end
