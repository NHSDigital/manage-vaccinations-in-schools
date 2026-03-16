# frozen_string_literal: true

RSpec::Matchers.define :matching_notify_email do |to:, template:|
  description do
    desc = "an email to #{to} with template :#{template}"
    desc +=
      " containing #{@expected_content_strings.map(&:inspect).join(", ")}" if @expected_content_strings
    desc
  end

  match do |actual|
    next false unless actual.is_a?(Hash)

    notify_template = NotifyTemplate.find(template, channel: :email)
    unless notify_template
      raise ArgumentError, "Unknown email template :#{template}"
    end
    next false unless actual[:email_address] == to
    expected_template_id = EmailDeliveryJob::PASSTHROUGH_TEMPLATE_ID
    next false unless actual[:template_id] == expected_template_id
    next true if @expected_content_strings.blank?

    personalisation = actual[:personalisation] || {}
    next false unless personalisation.key?(:body)

    content = [personalisation[:subject], personalisation[:body]].compact.join(
      "\n"
    )
    @expected_content_strings.all? { |s| content.include?(s) }
  end

  chain(:with_content_including) do |*strings|
    @expected_content_strings = strings
  end

  failure_message do
    base = "expected #{description}"

    if actual.nil?
      "#{base}, but no emails were sent"
    else
      "#{base}, but got email to #{actual[:email_address]} with template_id #{actual[:template_id]}"
    end
  end
end
