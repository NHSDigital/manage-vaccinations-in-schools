# frozen_string_literal: true

# When running inside Docker, inotify instances are shared with the host kernel
# and the default limit (128) is quickly exhausted. Setting LIVERELOAD_FORCE_POLLING
# switches listen to polling mode so livereload still works without hitting that limit.
# This is set automatically by docker-compose.yml; non-Docker developers are unaffected.
if ENV["LIVERELOAD_FORCE_POLLING"] == "true"
  Rails.application.config.hotwire_livereload.listen_options = { force_polling: true }
end
