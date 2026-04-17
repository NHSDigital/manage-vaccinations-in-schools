# frozen_string_literal: true

class PopulateOnePatientToManyParentsAssociation < ActiveRecord::Migration[8.1]
  def up
    Migrate::PopulateOnePatientToManyParentsAssociation.call
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
