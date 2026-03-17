# frozen_string_literal: true

class AppParentSummaryComponent < ViewComponent::Base
  def initialize(parent_relationship:, change_links: {})
    @parent_relationship = parent_relationship
    @parent = parent_relationship.parent
    @patient = parent_relationship.patient

    @change_links = change_links
  end

  def call
    govuk_summary_list do |summary_list|
      summary_list.with_row do |row|
        row.with_key { "Name" }

        if @parent.full_name.present?
          row.with_value { @parent.full_name }
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
        row.with_value { @parent_relationship.label }
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
          if @parent.email.present?
            row.with_value { email_address }
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
          if @parent.phone.present?
            row.with_value { phone_number }
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

        if @parent.contact_method_type.present?
          summary_list.with_row do |row|
            row.with_key { "Communication needs" }
            row.with_value { @parent.contact_method_description }
            if (href = @change_links[:phone])
              row.with_action(
                text: "Change",
                href:,
                visually_hidden_text: "communication needs"
              )
            end
          end
        end

        summary_list.with_row do |row|
          row.with_key { "Get updates by text message" }
          row.with_value { @parent.phone_receive_updates ? "Yes" : "No" }
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

  private

  delegate :govuk_summary_list, to: :helpers

  EMAIL_FAILURE_TEXTS = {
    "permanent_failure" => "Email address does not exist",
    "temporary_failure" => "Inbox not accepting messages right now"
  }.freeze

  def email_address
    delivery_status = @parent.email_delivery_status

    elements = [
      tag.p(@parent.email, class: "nhsuk-u-margin-0"),
      if (failure_text = EMAIL_FAILURE_TEXTS[delivery_status])
        render AppStatusComponent.new(
                 text: failure_text,
                 colour: "red",
                 small: true
               )
      end
    ].compact

    safe_join(elements)
  end

  PHONE_FAILURE_TEXTS = {
    "not_uk_mobile_number_failure" =>
      "Phone number is a landline not accepting text messages",
    "permanent_failure" => "Phone number does not exist",
    "temporary_failure" => "Inbox not accepting messages right now"
  }.freeze

  def phone_number
    delivery_status = @parent.sms_delivery_status

    elements = [
      tag.p(@parent.phone, class: "nhsuk-u-margin-0"),
      if (failure_text = PHONE_FAILURE_TEXTS[delivery_status])
        render AppStatusComponent.new(
                 text: failure_text,
                 colour: "red",
                 small: true
               )
      end
    ].compact

    safe_join(elements)
  end
end
