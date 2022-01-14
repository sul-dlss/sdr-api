
# This Dockerfile is optimized for running in development. That means it trades
# build speed for size. If we were using this for production, we might instead
# optimize for a smaller size at the cost of a slower build.
FROM ruby:3.0.3-alpine

# postgresql-client is required for invoke.sh
RUN apk add --update --no-cache  \
  build-base \
  postgresql-dev \
  postgresql-client \
  tzdata \
  libxml2-dev \
  libxslt-dev \
  yarn

RUN mkdir /app
WORKDIR /app

RUN gem update --system && \
  gem install bundler && \
  bundle config build.nokogiri --use-system-libraries

COPY Gemfile Gemfile.lock ./

RUN bundle config set without 'production'
RUN bundle install

COPY . .

CMD ["./docker/invoke.sh"]
