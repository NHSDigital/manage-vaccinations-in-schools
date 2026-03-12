# frozen_string_literal: true

class CreateGenericSchoolsForEachTeam < ActiveRecord::Migration[8.1]
  def up
    Team.find_each do |team|
      GenericLocationFactory.call(team:, academic_year: AcademicYear.current)
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
