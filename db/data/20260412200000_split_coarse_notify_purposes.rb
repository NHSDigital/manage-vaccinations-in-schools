# frozen_string_literal: true

class SplitCoarseNotifyPurposes < ActiveRecord::Migration[8.1]
  # Hardcoded mapping from template_id UUID → new purpose enum integer.
  # Self-contained so the migration is immune to future model refactors.
  #
  # Source: RETIRED_TEMPLATE_IDS + current ERB template frontmatter.
  # Only includes templates whose purpose is being split (consent_confirmation,
  # clinic_invitation, triage_vaccination_will_happen).
  TEMPLATE_PURPOSE_MAP = {
    # consent_confirmation (2) → consent_confirmation_given (14)
    "3179b434-4f44-4d47-a8ba-651b58c235fd" => 14, # retired: consent_confirmation_given
    "8eb8d05e-b8d8-4bf9-8a38-c009ae989a4e" => 14, # retired + active SMS: consent_confirmation_given
    "c6c8dbfc-b429-4468-bd0b-176e771b5a8e" => 14, # retired + active email: consent_confirmation_given
    "25473aa7-2d7c-4d1d-b0c6-2ac492f737c3" => 14, # retired: consent_confirmation_given
    "7cda7ae5-99a2-4c40-9a3e-1863e23f7a73" => 14, # retired: consent_confirmation_given

    # consent_confirmation (2) → consent_confirmation_refused (15)
    "e871e7d5-06be-48d1-81ba-38ddecae46e2" => 15, # retired: consent_confirmation_refused
    "eb34f3ab-0c58-4e56-b6b1-2c179270dfc3" => 15, # retired: consent_confirmation_refused
    "5a676dac-3385-49e4-98c2-fc6b45b5a851" => 15, # active email: consent_confirmation_refused
    "234b7479-1968-4f57-a6bf-20e402c8da39" => 15, # active SMS: consent_confirmation_refused

    # consent_confirmation (2) → consent_confirmation_given_triage (16)
    "604ee667-c996-471e-b986-79ab98d0767c" => 16, # retired: consent_confirmation_triage
    "35d621db-957b-4afb-9143-3e32398d2b87" => 16, # active email: consent_confirmation_triage

    # consent_confirmation (2) → consent_confirmation_given_clinic (17)
    "f2921e23-4b73-4e44-abbb-38b0e235db8e" => 17, # retired: consent_confirmation_clinic
    "1d050527-9a6c-4513-86d4-6955b98ac7d9" => 17, # active email: consent_confirmation_clinic

    # clinic_invitation (4) → clinic_initial_invitation (18)
    "88d21cfc-39f6-44a2-98c3-9588e7214ae4" => 18, # retired: invitation_to_clinic
    "fc99ac81-9eeb-4df8-9aa0-04f0eb48e37f" => 18, # retired: invitation_to_clinic_ryg
    "e1b6a2f6-728a-4de3-88ec-40194b354eac" => 18, # retired: invitation_to_clinic_rt5
    "ceea5ff5-2250-4eb2-ab35-4e9e840b2a6f" => 18, # active email: clinic_initial_invitation
    "5fe4fb4d-6f0a-4149-a80a-232bdfdf4f73" => 18, # active email: clinic_initial_invitation_ryg
    "17e63d67-53fc-4e9a-a533-74974412aac0" => 18, # active email: clinic_initial_invitation_rt5
    "790c9c72-729a-40d6-b44d-d480e38f0990" => 18, # active SMS: clinic_initial_invitation
    "8ef5712f-bb7f-4911-8f3b-19df6f8a7179" => 18, # active SMS: clinic_initial_invitation_ryg
    "7be79abb-7295-4e6f-8cfb-9597bfad2f56" => 18, # active SMS: clinic_initial_invitation_rt5

    # clinic_invitation (4) → clinic_subsequent_invitation (19)
    "a86a3b3f-a848-41d8-9a6f-d38174981388" => 19, # active email: clinic_subsequent_invitation
    "eee59c1b-3af4-4ccd-8653-940887066390" => 19, # active email: clinic_subsequent_invitation_ryg
    "ce7a6a1b-465e-4be4-b9e0-47ddb64f3adb" => 19, # active SMS: clinic_subsequent_invitation
    "018f146d-e7b7-4b63-ae26-bb07ca6fe2f9" => 19, # active SMS: clinic_subsequent_invitation_ryg

    # triage_vaccination_will_happen (6) stays as 6 for the base template.
    # Only the second dose variant gets a new purpose.
    "279c517c-4c52-4a69-96cb-31355bfa4e21" => 6,  # active email: triage_vaccination_will_happen
    "fa3c8dd5-4688-4b93-960a-1d422c4e5597" => 6,  # retired: triage_vaccination_will_happen

    # triage_vaccination_will_happen (6) → triage_vaccination_will_happen_second_dose (20)
    "6fd910fd-120c-4e58-9ef3-15ffc5bd6edc" => 20  # active email: triage_vaccination_will_happen_mmr_second_dose
  }.freeze

  def up
    TEMPLATE_PURPOSE_MAP
      .group_by { |_, value| value }
      .each do |purpose_int, pairs|
        uuids = pairs.map(&:first)
        NotifyLogEntry
          .where(template_id: uuids)
          .update_all(purpose: purpose_int)
      end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
