# syntax=docker/dockerfile:1

FROM ruby:3.4-slim AS deps

WORKDIR /build

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
      build-essential \
      git \
      ripgrep \
    && rm -rf /var/lib/apt/lists/*

COPY Gemfile Gemfile.lock zephira.gemspec ./
COPY lib/zephira/version.rb lib/zephira/version.rb

ENV BUNDLE_WITHOUT="development:test"

RUN bundle install --jobs 4

COPY . .
RUN gem build zephira.gemspec


FROM ruby:3.4-slim AS runtime

LABEL org.opencontainers.image.source="https://github.com/aarongough/zephira"
LABEL org.opencontainers.image.description="Command-line AI coding assistant in Ruby."
LABEL org.opencontainers.image.licenses="MIT"

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
      git \
      libreadline-dev \
      ripgrep \
    && rm -rf /var/lib/apt/lists/*

RUN groupadd --system zephira && \
    useradd --system --gid zephira --create-home --shell /bin/bash zephira && \
    mkdir -p /workspace && \
    chown zephira:zephira /workspace

COPY --from=deps /usr/local/bundle /usr/local/bundle
COPY --from=deps /build/zephira-*.gem /tmp/

RUN gem install --local --no-document /tmp/zephira-*.gem && \
    rm -f /tmp/zephira-*.gem

WORKDIR /workspace

USER zephira

CMD ["zephira"]
