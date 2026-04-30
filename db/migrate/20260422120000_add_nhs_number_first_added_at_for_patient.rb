# frozen_string_literal: true

class AddNHSNumberFirstAddedAtForPatient < ActiveRecord::Migration[8.1]
  def up
    add_column :patients, :nhs_number_first_added_at, :datetime
    add_index :patients, :nhs_number_first_added_at

    execute <<~SQL
      UPDATE patients
      SET nhs_number_first_added_at = created_at
      WHERE nhs_number IS NOT NULL
        AND nhs_number_first_added_at IS NULL
    SQL
  end

  def down
    remove_index :patients, :nhs_number_first_added_at
    remove_column :patients, :nhs_number_first_added_at
  end
end
