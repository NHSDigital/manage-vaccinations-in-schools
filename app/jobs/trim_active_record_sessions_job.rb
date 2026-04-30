# frozen_string_literal: true

# Based off https://github.com/rails/activerecord-session_store/blob/9198a952916df925f36ac2beab247296ee5c0341/lib/tasks/database.rake#L14-L20

class TrimActiveRecordSessionsJob < ApplicationJob
  def perform
    ActiveRecord::SessionStore::Session.where(
      "updated_at < ?",
      30.days.ago
    ).delete_all
  end
end
