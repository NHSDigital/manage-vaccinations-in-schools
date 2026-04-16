# frozen_string_literal: true

class CreateExports < ActiveRecord::Migration[8.1]
  def change
    create_table :exports do |t|
      t.references :exportable,
                   polymorphic: true,
                   null: false,
                   index: {
                     name: "index_exports_on_exportable"
                   }
      t.references :team, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true, index: false
      t.string :status, null: false, default: "pending"
      t.string :filename, null: false
      t.string :file_type, null: false
      t.binary :file_data
      t.timestamps
    end

    add_index :exports, :status
    add_index :exports, :created_at
  end
end
