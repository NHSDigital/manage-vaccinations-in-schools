# frozen_string_literal: true

class CreateSchoolMovesExports < ActiveRecord::Migration[8.1]
  def change
    create_table :school_moves_exports do |t|
      t.date :date_from
      t.date :date_to

      t.timestamps
    end
  end
end
