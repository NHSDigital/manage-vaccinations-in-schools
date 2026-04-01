# frozen_string_literal: true

VALIDATOR_MESSAGE_KEYS = {
  ActiveRecord::Validations::PresenceValidator => :blank,
  ActiveModel::Validations::PresenceValidator => :blank,
  ActiveModel::Validations::InclusionValidator => :inclusion,
  ActiveModel::Validations::ExclusionValidator => :exclusion,
  ActiveModel::Validations::FormatValidator => :invalid,
  ActiveModel::Validations::LengthValidator => nil,
  ActiveModel::Validations::NumericalityValidator => nil,
  ActiveRecord::Validations::UniquenessValidator => :taken
}.freeze

Rails.application.eager_load!

ALL_MODELS =
  ActiveRecord::Base.descendants.reject(&:abstract_class?) +
    ObjectSpace.each_object(Class).select { it < ActiveModel::Model }

VALIDATIONS_TO_CHECK =
  ALL_MODELS
    .sort_by(&:name)
    .flat_map do |model|
      model.validators.flat_map do |validator|
        message_key = VALIDATOR_MESSAGE_KEYS[validator.class]
        next [] if message_key.nil?
        next [] if validator.options[:message].present?

        validator.attributes.filter_map do |attribute|
          [model, attribute, message_key] unless attribute == :base
        end
      end
    end

VALIDATIONS_TO_CHECK.freeze

RSpec.describe "Validation messages" do
  VALIDATIONS_TO_CHECK.each do |model, attribute, message_key|
    it "#{model.name}##{attribute} has a custom #{message_key} message" do
      scope =
        if model < ActiveRecord::Base
          "activerecord.errors.models"
        else
          "activemodel.errors.models"
        end

      model_key = model.model_name.i18n_key.to_s.tr("/", ".")

      expect(
        I18n.exists?(
          "#{scope}.#{model_key}.attributes.#{attribute}.#{message_key}"
        )
      ).to(
        be(true),
        "#{model.name}##{attribute} uses the default :#{message_key} " \
          "message. Add a custom message via I18n or the message: option."
      )
    end
  end
end
