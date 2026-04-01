# frozen_string_literal: true

class ConsentFollowUpForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :decision_stands, :string

  validates :decision_stands,
            inclusion: {
              in: %w[true false],
              message: "Select yes or no"
            }

  def decision_stands? = decision_stands == "true"
end
