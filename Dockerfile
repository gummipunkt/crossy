FROM ruby:3.3.4-slim

# Install OS packages
RUN apt-get update -y \
  && apt-get install -y --no-install-recommends \
    build-essential \
    libpq-dev \
    postgresql-client \
    curl \
    git \
    tzdata \
    imagemagick \
    nodejs \
    npm \
  && rm -rf /var/lib/apt/lists/*

ENV APP_HOME=/app \
    RAILS_ENV=development \
    RACK_ENV=development \
    GEM_HOME=/usr/local/bundle \
    BUNDLE_PATH=/usr/local/bundle \
    PATH="/usr/local/bundle/bin:${PATH}"

WORKDIR ${APP_HOME}

# Pre-create bundler dirs to allow caching
RUN mkdir -p ${APP_HOME}/server

WORKDIR ${APP_HOME}

# Install bundler
RUN gem install bundler -v 2.5.9 --no-document

# Default command will be overridden by docker-compose; keep it simple
CMD ["bash", "-lc", "ruby -v && bundle -v"]


