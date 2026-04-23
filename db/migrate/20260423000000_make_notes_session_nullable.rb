# frozen_string_literal: true

class MakeNotesSessionNullable < ActiveRecord::Migration[8.0]
  def change
    change_column_null :notes, :session_id, true
  end
end
