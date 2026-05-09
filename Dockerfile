# syntax=docker/dockerfile:1

FROM ruby:3.4-slim AS deps

WORKDIR /build

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
      build-essential \
      git \
    && rm -rf /var/lib/apt/lists/*

COPY Gemfile Gemfile.lock zephira.gemspec ./
COPY lib/zephira/version.rb lib/zephira/version.rb

RUN bundle config set --local deployment true && \
    bundle config set --local without "development test" && \
    bundle install --jobs 4


FROM ruby:3.4-slim AS runtime

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
      libreadline-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=deps /build/vendor /app/vendor
COPY --from=deps /build/.bundle /app/.bundle
COPY --from=deps /usr/local/bundle /usr/local/bundle

COPY . .

RUN gem build zephira.gemspec && \
    gem install --local --no-document zephira-*.gem && \
    rm -f zephira-*.gem

WORKDIR /workspace

CMD ["zephira"]
