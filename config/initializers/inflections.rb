# frozen_string_literal: true

# Be sure to restart your server when you modify this file.

# Add new inflection rules using the following format. Inflections
# are locale specific, and you may define rules for as many different
# locales as you wish. All of these examples are active by default:
# ActiveSupport::Inflector.inflections(:en) do |inflect|
#   inflect.plural /^(ox)$/i, "\\1en"
#   inflect.singular /^(ox)en/i, "\\1"
#   inflect.irregular "person", "people"
#   inflect.uncountable %w( fish sheep )
# end

ActiveSupport::Inflector.inflections(:en) do |inflect|
  inflect.acronym "API"
  inflect.acronym "CIS2"
  inflect.acronym "CLI"
  inflect.acronym "CSRF"
  inflect.acronym "CSV"
  inflect.acronym "DPS"
  inflect.acronym "DfE"
  inflect.acronym "FHIR"
  inflect.acronym "GIAS"
  inflect.acronym "GIS"
  inflect.acronym "GP"
  inflect.acronym "HCA"
  inflect.acronym "JWKS"
  inflect.acronym "NHS"
  inflect.acronym "OAuth2"
  inflect.acronym "ODS"
  inflect.acronym "OpenID"
  inflect.acronym "PDS"
  inflect.acronym "PGD"
  inflect.acronym "QA"
  inflect.acronym "SMS"
  inflect.acronym "URN"

  inflect.irregular "batch", "batches"
  inflect.irregular "child", "children"
end
