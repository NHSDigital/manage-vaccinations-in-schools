# frozen_string_literal: true

class SetSchoolOnSchoolMoves < ActiveRecord::Migration[8.1]
  def up
    SchoolMove
      .where(school_id: nil)
      .find_each do |school_move|
        # We use a private method here which picks the right school (either
        #  the unknown school or the home-educated school).
        school = school_move.send(:destination_school)
        school_move.update!(school:, team_id: nil, home_educated: nil)
      end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
