# frozen_string_literal: true

class FeatureFlagFactory
  def self.call
    names =
      YAML.safe_load(
        File.read(Rails.root.join("config/feature_flags.yml"))
      ).keys

    Flipper::Adapters::Strict.with_sync_mode do
      names.each { Flipper.add(it) unless Flipper.exist?(it) }
    end

    Flipper.features.each do |feature|
      feature.remove unless feature.name.to_s.in?(names)
    end
  end

  FEATURES_FOR_DEVELOPMENT = %i[
    dev_tools
    testing_api
    vaccinating_16_plus_year_olds
  ].freeze

  def self.enable_for_development!(check_rails_env: true)
    if check_rails_env && !(Rails.env.development? || Rails.env.end_to_end?)
      raise "These flags should only be enabled in development or end_to_end."
    end

    FEATURES_FOR_DEVELOPMENT.each { Flipper.enable(it) }
  end
end
