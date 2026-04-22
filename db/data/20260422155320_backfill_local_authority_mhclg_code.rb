# frozen_string_literal: true

class BackfillLocalAuthorityMhclgCode < ActiveRecord::Migration[8.1]
  def up
    scope = Patient.where(local_authority_mhclg_code: nil)
    total = scope.count
    Rails.logger.debug "Checking #{total} patients..."

    processed = 0
    updated = 0
    skipped_no_postcode = 0
    skipped_no_match = 0

    scope.find_each do |patient|
      processed += 1
      next skipped_no_postcode += 1 if patient.address_postcode.blank?

      la_code =
        LocalAuthority.for_postcode(patient.address_postcode)&.mhclg_code
      if la_code
        patient.update_column(:local_authority_mhclg_code, la_code)
        updated += 1
      else
        skipped_no_match += 1
      end

      if (processed % 10_000).zero?
        Rails.logger.debug "Processed #{processed}/#{total} (updated: #{updated})"
      end
    end

    Rails.logger.debug "Done. Processed #{processed} patients."
    Rails.logger.debug "  Updated: #{updated}"
    Rails.logger.debug "  Skipped (no postcode): #{skipped_no_postcode}"
    Rails.logger.debug "  Skipped (no LA match): #{skipped_no_match}"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
