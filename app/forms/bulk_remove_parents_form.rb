# frozen_string_literal: true

class BulkRemoveParentsForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  BATCH_SIZE = 10

  attr_accessor :current_user
  attr_reader :import, :consents

  attribute :remove_option, :string

  validates :remove_option,
            inclusion: {
              in: %w[unconsented_only all]
            },
            if: :consents_present?

  def initialize(import:, consents:, current_user:, **attributes)
    @import = import
    @consents = consents
    @current_user = current_user
    super(attributes)
  end

  def save!
    return false unless valid?
    import.update!(status: :removing_parent_relationships)

    import
      .parent_relationship_ids
      .each_slice(BATCH_SIZE) do |batch_ids|
        BulkRemoveParentRelationshipsSidekiqJob.perform_async(
          import.to_global_id.to_s,
          batch_ids,
          current_user.id,
          remove_option
        )
      end

    true
  end

  private

  def consents_present?
    @consents.any?
  end
end
