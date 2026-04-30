# frozen_string_literal: true

RSpec::Matchers.matcher :deliver_email do |template_name = nil|
  supports_block_expectations

  define_singleton_method :chain_delegate do |*methods|
    methods.each do |method|
      chain(method) { |*a, **h| matcher.send(method, *a, **h) }
    end
  end

  chain_delegate :at_least, :at_most, :once, :times, :twice

  define_method :matcher do
    @matcher ||=
      if @params.nil?
        have_enqueued_job(EmailDeliveryJob).with(
          *[template_name].compact,
          any_args
        )
      else
        have_enqueued_job(EmailDeliveryJob).with(
          *[template_name].compact,
          **@params
        )
      end
  end

  chain :with do |params = {}|
    @params = params
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

  # TODO: copy the error message from the have_enqueued_job but only list jobs
  #       enqueued for EmailDeliveryJob
  failure_message { <<~MESSAGE }
      expected #{template_name} email to have been delivered
      #{@error}
    MESSAGE
end
