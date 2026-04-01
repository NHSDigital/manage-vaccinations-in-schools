# frozen_string_literal: true

# == Schema Information
#
# Table name: consent_form_programmes
#
#  id                  :bigint           not null, primary key
#  disease_types       :enum             is an Array
#  follow_up_requested :boolean
#  notes               :text             default(""), not null
#  programme_type      :enum             not null
#  reason_for_refusal  :integer
#  response            :integer
#  vaccine_methods     :integer          default([]), not null, is an Array
#  without_gelatine    :boolean
#  consent_form_id     :bigint           not null
#
# Indexes
#
#  idx_on_programme_type_consent_form_id_805eb5d685  (programme_type,consent_form_id) UNIQUE
#  index_consent_form_programmes_on_consent_form_id  (consent_form_id)
#
# Foreign Keys
#
#  fk_rails_...  (consent_form_id => consent_forms.id) ON DELETE => cascade
#
describe ConsentFormProgramme do
  let(:programme) { Programme.mmr }
  let(:session) { create(:session, programmes: [programme]) }
  let(:consent_form) { create(:consent_form, :given, session:) }
  let(:consent_form_programme) { consent_form.consent_form_programmes.first }

  describe "#vaccines" do
    context "when there are MMR and MMRV vaccines" do
      before do
        consent_form_programme.update!(
          disease_types: Programme::Variant::DISEASE_TYPES[programme.type]
        )
      end

      it "only returns MMR vaccines" do
        # Ensure that the MMRV vaccines do actually exist!
        expect(Vaccine.where(brand: %w[ProQuad Priorix-Tetra]).count).to eq(2)

        mmr_vaccines = Vaccine.where(brand: ["Priorix", "MMR VaxPro"])
        expect(consent_form_programme.vaccines).to match_array(mmr_vaccines)
      end
    end
  end
end
