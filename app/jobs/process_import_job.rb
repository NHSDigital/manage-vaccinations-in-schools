# frozen_string_literal: true

class ProcessImportJob < ApplicationJob
  include SingleConcurrencyConcern

  queue_as :imports

  def perform(import)
    return if import.processed?

    SemanticLogger.tagged(import_id: import.id) do
      Sentry.set_tags(import_id: import.id)

      import.parse_rows!

      return if import.errors.any?
      return if import.rows_are_invalid?

      import.process!
    end
  end
end
