# frozen_string_literal: true

class SchoolMovesExportForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :date_from, :date
  attribute :date_to, :date
end
