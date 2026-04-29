# frozen_string_literal: true

module RSpec
  module Support
    module CaptureOutputHelper
      def capture_output(input: nil)
        require "stringio"
        output = StringIO.new
        original_stdout = $stdout
        $stdout = output
        original_input =
          if input
            oin = $stdin
            $stdin = StringIO.new(input)
            oin
          end
        stub_const("ProgressBar::Output::DEFAULT_OUTPUT_STREAM", output)

        # Pretend that the terminal window is wide, so table cells aren't truncated.
        allow(TableTennis::Util::Console).to receive(:winsize).and_return(
          [48, 220]
        )

        yield

        output.string
      rescue SystemExit
        output.string
      ensure
        $stdout = original_stdout
        $stdin = original_input if input
      end

      def capture_error
        require "stringio"
        error = StringIO.new
        original_stderr = $stderr
        $stderr = error
        yield
        error.string
      rescue SystemExit => e
        [error.string, e]
      ensure
        $stderr = original_stderr
      end
    end
  end
end

RSpec.configure { |config| config.include(RSpec::Support::CaptureOutputHelper) }
