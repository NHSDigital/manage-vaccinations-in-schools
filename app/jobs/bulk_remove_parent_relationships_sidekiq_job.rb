# frozen_string_literal: true

class BulkRemoveParentRelationshipsSidekiqJob < ApplicationJobSidekiq
  sidekiq_options queue: :imports

  def perform(
    import_global_id,
    parent_relationship_ids_batch,
    user_id,
    remove_option
  )
    BulkRemoveParentRelationshipsJob.new.perform(
      import_global_id,
      parent_relationship_ids_batch,
      user_id,
      remove_option
    )
  end
end
