# frozen_string_literal: true

# rubocop:disable Rails/ApplicationJob
class ApplicationJobActiveJob < ActiveJob::Base
  discard_on ActiveJob::DeserializationError
end
# rubocop:enable Rails/ApplicationJob
