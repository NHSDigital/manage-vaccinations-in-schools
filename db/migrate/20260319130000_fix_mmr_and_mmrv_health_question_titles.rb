# frozen_string_literal: true

class FixMmrAndMmrvHealthQuestionTitles < ActiveRecord::Migration[8.0]
  WRONG_MMR_TITLE =
    "Has your child had a severe allergic reaction (anaphylaxis) to a previous dose of MMR or any other vaccine?"

  RIGHT_MMR_TITLE =
    "Has your child had a severe allergic reaction (anaphylaxis) to " \
      "a previous dose of MMR or any other measles, mumps or rubella vaccine?"

  WRONG_MMRV_TITLE =
    "Has your child had a severe allergic reaction (anaphylaxis) to a previous dose of MMRV or any other vaccine?"

  RIGHT_MMRV_TITLE =
    "Has your child had a severe allergic reaction (anaphylaxis) to " \
      "a previous dose of MMRV or any other measles, mumps, rubella or varicella (chickenpox) vaccine?"

  def up
    mmr_vaccine_ids =
      Vaccine.where(disease_types: %w[measles mumps rubella]).pluck(:id)

    mmrv_vaccine_ids =
      Vaccine.where(disease_types: %w[measles mumps rubella varicella]).pluck(
        :id
      )

    HealthQuestion.where(
      vaccine_id: mmr_vaccine_ids,
      title: WRONG_MMR_TITLE
    ).update_all(title: RIGHT_MMR_TITLE)

    HealthQuestion.where(
      vaccine_id: mmrv_vaccine_ids,
      title: WRONG_MMRV_TITLE
    ).update_all(title: RIGHT_MMRV_TITLE)
  end

  def down
    mmr_vaccine_ids =
      Vaccine.where(disease_types: %w[measles mumps rubella]).pluck(:id)

    mmrv_vaccine_ids =
      Vaccine.where(disease_types: %w[measles mumps rubella varicella]).pluck(
        :id
      )

    HealthQuestion.where(
      vaccine_id: mmr_vaccine_ids,
      title: RIGHT_MMR_TITLE
    ).update_all(title: WRONG_MMR_TITLE)

    HealthQuestion.where(
      vaccine_id: mmrv_vaccine_ids,
      title: RIGHT_MMRV_TITLE
    ).update_all(title: WRONG_MMRV_TITLE)
  end
end
