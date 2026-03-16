# frozen_string_literal: true

RSpec::Matchers.define :matching_notify_sms do |phone_number:, template:|
  description do
    desc = "an SMS to #{phone_number} with template :#{template}"
    desc +=
      " containing #{@expected_content_strings.map(&:inspect).join(", ")}" if @expected_content_strings
    desc
  end

  match do |actual|
    next false unless actual.is_a?(Hash)

    notify_template = NotifyTemplate.find(template, channel: :sms)
    unless notify_template
      raise ArgumentError, "Unknown SMS template :#{template}"
    end
    next false unless actual[:phone_number] == phone_number
    expected_template_id = SMSDeliveryJob::PASSTHROUGH_TEMPLATE_ID
    next false unless actual[:template_id] == expected_template_id
    next true if @expected_content_strings.blank?

    personalisation = actual[:personalisation] || {}
    next false unless personalisation.key?(:body)

    content = personalisation[:body]
    @expected_content_strings.all? { |s| content.include?(s) }
  end

  chain(:with_content_including) do |*strings|
    @expected_content_strings = strings
  end

  failure_message do
    base = "expected #{description}"

    if actual.nil?
      "#{base}, but no SMS messages were sent"
    else
      "#{base}, but got SMS to #{actual[:phone_number]} with template_id #{actual[:template_id]}"
    end
  end
end
