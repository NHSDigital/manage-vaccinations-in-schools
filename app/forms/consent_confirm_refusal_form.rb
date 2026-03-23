# frozen_string_literal: true

class ConsentConfirmRefusalForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :confirmed, :string
  attribute :notes, :string

  validates :confirmed,
            inclusion: {
              in: %w[true false],
              message: "Select yes or no"
            }
  validates :notes, length: { maximum: 1000 }

  def confirmed? = confirmed == "true"
end
