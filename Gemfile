# frozen_string_literal: true

source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby file: ".ruby-version"
gem "rails", "8.1.3"

# Framework gems
gem "bootsnap", require: false
gem "cssbundling-rails"
gem "falcon"
gem "falcon-rails"
gem "jsbundling-rails"
gem "localhost"
gem "pg"
gem "propshaft"
gem "turbo-rails"

# Load before sentry-ruby to avoid race condition
gem "stackprof"

# 3rd party gems
gem "activerecord-import"
gem "activerecord-session_store"
gem "active_record_union"
gem "amazing_print"
gem "array_enum"
gem "audited", github: "tvararu/audited", branch: "encryption"
gem "aws-sdk-cloudwatch"
gem "caxlsx"
gem "charlock_holmes"
gem "config"
gem "csv"
gem "data_migrate"
gem "devise"
gem "discard"
gem "dry-cli"
gem "factory_bot_rails"
gem "faker"
gem "faraday"
gem "fhir_models"
gem "flipper"
gem "flipper-active_record"
gem "flipper-ui"
gem "govuk-components"
gem "govuk_design_system_formbuilder"
gem "govuk_markdown"
gem "indefinite_article"
gem "jsonb_accessor"
gem "jwt"
gem "mechanize"
gem "notifications-ruby-client"
gem "okcomputer"
gem "omniauth_openid_connect"
gem "omniauth-rails_csrf_protection"
gem "pagy"
gem "phonelib"
gem "prometheus_exporter",
    github: "discourse/prometheus_exporter",
    branch: "main" #TODO: replace with version > 2.3.1 when released
gem "pstore"
gem "pundit"
gem "rails_semantic_logger"
gem "rainbow"
gem "redis"
gem "ruby-progressbar"
gem "rubyzip"
gem "scenic"
gem "sentry-rails"
gem "sentry-ruby"
gem "sentry-sidekiq"
gem "sidekiq"
gem "sidekiq-scheduler"
gem "sidekiq-throttled"
gem "sidekiq-unique-jobs"
gem "splunk-sdk-ruby"
gem "table_tennis"
gem "tzinfo-data", platforms: %i[jruby windows]
gem "uk_postcode"
gem "wicked"
gem "with_advisory_lock"

group :development, :test, :end_to_end do
  gem "brakeman", require: false
  gem "debug", platforms: %i[mri windows]
  gem "factory_bot_instruments"
  gem "parallel_tests"
  gem "pry-rails"
  gem "rspec-rails"
end

group :development, :end_to_end do
  gem "annotaterb", require: false
  gem "asciidoctor"
  gem "asciidoctor-diagram"
  gem "aws-sdk-accessanalyzer"
  gem "aws-sdk-ec2"
  gem "aws-sdk-ecr"
  gem "aws-sdk-iam"
  gem "aws-sdk-rds"
  gem "aws-sdk-s3"
  gem "hotwire-livereload"
  gem "prettier_print", require: false
  gem "rladr"
  gem "rubocop-govuk", require: false
  gem "ruby-prof", require: false
  gem "rufo", require: false
  gem "solargraph", require: false
  gem "solargraph-rails", require: false
  gem "syntax_tree", require: false
  gem "syntax_tree-haml", require: false
  gem "syntax_tree-rbs", require: false
  gem "web-console"
end

group :test do
  gem "capybara"
  gem "capybara_accessible_selectors",
      github: "citizensadvice/capybara_accessible_selectors"
  gem "capybara-screenshot"
  gem "climate_control"
  gem "cuprite"
  gem "database_cleaner-active_record"
  gem "its"
  gem "rack_session_access"
  gem "rspec"
  gem "rspec-html-matchers"
  gem "rspec-sidekiq"
  gem "rubyXL"
  gem "shoulda-matchers"
  gem "simplecov", require: false
  gem "webmock"
end
