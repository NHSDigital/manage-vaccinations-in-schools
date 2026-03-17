# frozen_string_literal: true

class AppConsentParentSummaryComponent < ViewComponent::Base
  def initialize(consentable, change_links: {})
    @consentable = consentable
    @patient = @consentable.patient if @consentable.is_a?(Consent)
    @change_links = change_links
  end

  def call
    govuk_summary_list do |summary_list|
      summary_list.with_row do |row|
        row.with_key { "Name" }

        if (name = consent_parent_name(@consentable)).present?
          row.with_value { name }
          if (href = @change_links[:name])
            row.with_action(text: "Change", href:, visually_hidden_text: "name")
          end
        elsif (href = @change_links[:name])
          row.with_value { link_to("Add name", href) }
        else
          row.with_value { "Not provided" }
        end
      end

      summary_list.with_row do |row|
        row.with_key { "Relationship" }
        row.with_value { @consentable.who_responded }
        if (href = @change_links[:relationship])
          row.with_action(
            text: "Change",
            href:,
            visually_hidden_text: "relationship"
          )
        end
      end

      unless @patient&.restricted?
        summary_list.with_row do |row|
          row.with_key { "Email address" }
          if (email = consent_parent_email(@consentable)).present?
            row.with_value { tag.p(email, class: "nhsuk-u-margin-0") }
            if (href = @change_links[:email])
              row.with_action(
                text: "Change",
                href:,
                visually_hidden_text: "email address"
              )
            end
          elsif (href = @change_links[:email])
            row.with_value { link_to("Add email address", href) }
          else
            row.with_value { "Not provided" }
          end
        end

        summary_list.with_row do |row|
          row.with_key { "Phone number" }
          if (phone = consent_parent_phone(@consentable)).present?
            row.with_value { tag.p(phone, class: "nhsuk-u-margin-0") }
            if (href = @change_links[:phone])
              row.with_action(
                text: "Change",
                href:,
                visually_hidden_text: "phone number"
              )
            end
          elsif (href = @change_links[:phone])
            row.with_value { link_to("Add phone number", href) }
          else
            row.with_value { "Not provided" }
          end
        end

        summary_list.with_row do |row|
          row.with_key { "Get updates by text message" }
          row.with_value do
            consent_parent_phone_receive_updates(@consentable) ? "Yes" : "No"
          end
          if (href = @change_links[:phone])
            row.with_action(
              text: "Change",
              href:,
              visually_hidden_text: "get updates by text message"
            )
          end
        end
      end
    end
  end

  delegate :govuk_summary_list,
           :link_to,
           :consent_parent_name,
           :consent_parent_email,
           :consent_parent_phone,
           :consent_parent_phone_receive_updates,
           to: :helpers
end
