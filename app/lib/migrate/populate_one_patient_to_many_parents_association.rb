# frozen_string_literal: true

module Migrate
  class PopulateOnePatientToManyParentsAssociation
    def initialize
    end

    def call
      Parent
        .includes(:parent_relationships)
        .find_each do |parent|
          parent
            .parent_relationships
            .each_with_index do |parent_relationship, index|
            if index.zero?
              parent.update!(
                patient: parent_relationship.patient,
                type: parent_relationship.type,
                other_name: parent_relationship.other_name
              )
            else
              Parent.create!(
                parent
                  .attributes
                  .except("id", "created_at", "updated_at")
                  .merge(
                    patient: parent_relationship.patient,
                    type: parent_relationship.type,
                    other_name: parent_relationship.other_name
                  )
              )
            end
          end
        end
    end

    def self.call(...) = new(...).call

    private_class_method :new
  end
end
