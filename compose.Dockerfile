FROM ruby:4.0.1

# Install system dependencies required to build native gems and run the app.
# Matches the packages in the production Dockerfile (Dockerfile) to keep
# dev and prod environments as close as possible.
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
      build-essential \
      curl \
      git \
      jq \
      libicu-dev \
      libjemalloc2 \
      libpq-dev \
      libvips \
      libyaml-dev \
      node-gyp \
      pkg-config \
      postgresql-client \
      python-is-python3 \
      sudo \
      zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js at the exact version used in production (see .node-version)
ARG NODE_VERSION=22.15.0
ARG YARN_VERSION=1.22.19
ENV PATH=/usr/local/node/bin:$PATH
RUN curl -sL --ssl https://github.com/nodenv/node-build/archive/master.tar.gz | tar xz -C /tmp/ && \
    /tmp/node-build-master/bin/node-build "${NODE_VERSION}" /usr/local/node && \
    npm install --ignore-scripts -g yarn@"$YARN_VERSION" && \
    rm -rf /tmp/node-build-master

# Install foreman for running the Procfile
RUN gem install foreman

# Create a non-root user matching the VS Code Dev Container convention.
# The UID/GID defaults to 1000, which matches most Linux hosts and avoids
# file permission issues with the mounted workspace.
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=${USER_UID}

RUN groupadd --gid ${USER_GID} ${USERNAME} && \
    useradd --uid ${USER_UID} --gid ${USER_GID} -m ${USERNAME} && \
    echo "${USERNAME} ALL=(root) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME} && \
    chmod 0440 /etc/sudoers.d/${USERNAME}

# Ensure the bundle directory is writable by the non-root user so that
# `bundle install` works without sudo. Docker copies this ownership into the
# named volume on first use.
RUN mkdir -p /usr/local/bundle && chown -R ${USERNAME}:${USER_GID} /usr/local/bundle

USER ${USERNAME}

WORKDIR /workspaces/manage-vaccinations-in-schools
