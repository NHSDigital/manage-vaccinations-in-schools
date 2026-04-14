# frozen_string_literal: true

class AddParentAttributesToParentRelationships < ActiveRecord::Migration[8.1]
  def change
    change_table :parent_relationships, bulk: true do |t|
      t.string :email, null: true
      t.string :full_name, null: true
      t.string :phone, null: true
      t.string :phone_receive_updates, null: true
      t.text :contact_method_other_details, null: true
      t.string :contact_method_type, null: true
    end
  end
end
