#!/usr/bin/env -S falcon-host
# frozen_string_literal: true

require "falcon/environment/rack"

hostname = File.basename(__dir__)

service hostname do
  include Falcon::Environment::Rack

  preload "preload.rb"

  count ENV.fetch("WEB_CONCURRENCY", 2).to_i

  port { ENV.fetch("PORT", 4000).to_i }

  protocol do
    case ENV.fetch("HTTP_VERSION", "http1")
    when "http2"
      Async::HTTP::Protocol::HTTP2
    else
      Async::HTTP::Protocol::HTTP11
    end
  end

  scheme { ENV.fetch("HTTP_PROTOCOL", "http") }

  endpoint do
    options = { protocol: protocol }

    if scheme == "https"
      authority = Localhost::Authority.fetch(path: "/rails/tmp")
      ssl_context = authority.server_context
      alpn_names = protocol.names
      ssl_context.alpn_select_cb = ->(offered) { (offered & alpn_names).first }
      options[:ssl_context] = ssl_context
    end

    Async::HTTP::Endpoint.parse("#{scheme}://0.0.0.0:#{port}").with(**options)
  end
end

unless ENV["SERVICE_DIRECT_PORT"].to_s.empty?
  service "#{hostname}-http" do
    include Falcon::Environment::Rack

    preload "preload.rb"

    count 1

    protocol { Async::HTTP::Protocol::HTTP11 }
    scheme { "http" }

    rack_app do
      app = super()
      allowed_paths = %w[/api/reporting/ /up]

      ->(env) do
        if allowed_paths.any? { |path| env["PATH_INFO"].start_with?(path) }
          app.call(env)
        else
          [
            403,
            { "content-type" => "text/plain" },
            [
              "Path #{env["PATH_INFO"]} is not allowed. Allowed paths: #{allowed_paths.join(", ")}"
            ]
          ]
        end
      end
    end

    endpoint do
      Async::HTTP::Endpoint.parse(
        "http://0.0.0.0:#{ENV["SERVICE_DIRECT_PORT"]}"
      ).with(protocol: protocol)
    end
  end
end
