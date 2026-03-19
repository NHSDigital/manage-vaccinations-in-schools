# frozen_string_literal: true

class MakeSchoolMoveSchoolNotNull < ActiveRecord::Migration[8.1]
  def change
    change_column_null :school_moves, :school_id, false
  end
end
