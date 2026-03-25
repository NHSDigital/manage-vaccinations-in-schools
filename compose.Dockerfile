# syntax = docker/dockerfile:1.4
# check=error=true

# Make sure RUBY_VERSION matches the Ruby version in .ruby-version
ARG RUBY_VERSION=4.0.2
FROM docker.io/library/ruby:$RUBY_VERSION-slim

# Rails app lives here
WORKDIR /rails

# Install base packages (mirrors the base stage in Dockerfile)
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl libjemalloc2 \
    libvips libicu-dev postgresql-client jq ca-certificates && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Install packages needed to build gems and node modules
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git libpq-dev \
      libyaml-dev node-gyp pkg-config python-is-python3 zlib1g-dev && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Install JavaScript dependencies (mirrors the build stage in Dockerfile)
ARG NODE_VERSION=22.15.0
ARG YARN_VERSION=1.22.19
ENV PATH=/usr/local/node/bin:$PATH
RUN curl -sL --ssl https://github.com/nodenv/node-build/archive/master.tar.gz | tar xz -C /tmp/ && \
    /tmp/node-build-master/bin/node-build "${NODE_VERSION}" /usr/local/node && \
    npm install --ignore-scripts -g yarn@"$YARN_VERSION" && \
    rm -rf /tmp/node-build-master

# Install foreman for running Procfile.dev
RUN gem install foreman

# Development environment — gems and code are mounted at runtime via volumes,
# so BUNDLE_DEPLOYMENT must be off and BUNDLE_WITHOUT must be empty.
ENV RAILS_ENV="development" \
    NODE_ENV="development" \
    BUNDLE_PATH="/usr/local/bundle" \
    XDG_STATE_HOME="/rails/tmp"

# Run and own only the runtime files as a non-root user for security
# (mirrors the final stage in Dockerfile)
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    mkdir -p db log storage tmp /usr/local/bundle && \
    chown -R rails:rails db log storage tmp /usr/local/bundle

USER 1000:1000
