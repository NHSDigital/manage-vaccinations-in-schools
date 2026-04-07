# frozen_string_literal: true

# == Schema Information
#
# Table name: contacts
#
#  id                      :bigint           not null, primary key
#  contact_method          :enum             not null
#  email                   :string
#  full_name               :string           not null
#  phone                   :string
#  phone_receive_updates   :boolean          default(FALSE), not null
#  relationship            :enum             not null
#  relationship_other_name :string
#  source                  :enum             not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  patient_id              :bigint           not null
#
# Indexes
#
#  index_contacts_on_patient_id            (patient_id)
#  index_contacts_on_patient_id_and_email  (patient_id,email) UNIQUE
#  index_contacts_on_patient_id_and_phone  (patient_id,phone) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (patient_id => patients.id)
#
describe Contact do
  describe "validations" do
    it { should validate_presence_of(:full_name) }
    it { should validate_presence_of(:source) }
    it { should validate_presence_of(:contact_method) }
    it { should validate_presence_of(:relationship) }

    it { should_not validate_presence_of(:email) }
    it { should_not validate_presence_of(:phone) }
  end

  it_behaves_like "a model with a normalised email address"
  it_behaves_like "a model with a normalised phone number"
end
