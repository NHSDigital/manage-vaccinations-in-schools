# frozen_string_literal: true

class CreateContacts < ActiveRecord::Migration[8.1]
  def change
    create_enum "contact_method", %w[phone email]
    create_enum "contact_relationship", %w[father guardian mother other unknown]
    create_enum "contact_source",
                %w[child_record class_list consent_response sais]

    create_table :contacts do |t|
      t.references :patient, null: false, foreign_key: true
      t.enum :contact_method, null: false, enum_type: "contact_method"
      t.string :full_name, null: false
      t.string :email
      t.string :phone
      t.boolean :phone_receive_updates, default: false, null: false
      t.enum :relationship, null: false, enum_type: "contact_relationship"
      t.enum :source, null: false, enum_type: "contact_source"
      t.string :relationship_other_name
      t.timestamps
    end

    add_index :contacts, %i[patient_id email], unique: true
    add_index :contacts, %i[patient_id phone], unique: true
  end
end
