# frozen_string_literal: true

RSpec::Matchers.matcher :deliver_sms do |template_name = nil|
  supports_block_expectations

  define_singleton_method :chain_delegate do |*methods|
    methods.each do |method|
      chain(method) { |*a, **h| matcher.send(method, *a, **h) }
    end
  end

  chain_delegate :at_least, :at_most, :once, :times, :twice

  define_method :matcher do
    @matcher ||=
      enqueue_sidekiq_job(SMSDeliveryJob).with(
        template_name&.to_s.presence || anything,
        @params || anything
      )
  end

  chain :with do |params = {}|
    @params = params.stringify_keys
  end

  match do |actual|
    expect { actual.call }.to matcher
  rescue RSpec::Expectations::ExpectationNotMetError => e
    @error = e
    raise
  end

  match_when_negated do |actual|
    expect { actual.call }.not_to matcher
  rescue RSpec::Expectations::ExpectationNotMetError => e
    @error = e
    raise
  end

  # TODO: copy the error message from the enqueue_sidekiq_job but only list
  #  jobs enqueued for SMSDeliveryJob
  failure_message { <<~MESSAGE }
      expected #{template_name} sms to have been delivered
      #{@error}
    MESSAGE
end
