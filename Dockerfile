FROM ruby:3.4.1-bookworm

RUN curl -fsSL https://deb.nodesource.com/setup_current.x | bash -

RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
  && apt-get -y install --no-install-recommends \
      postgresql-client postgresql-contrib libpq-dev \
      libxml2-dev clang nodejs

RUN mkdir /app
WORKDIR /app

RUN npm install -g yarn

RUN gem update --system && \
  gem install bundler && \
  bundle config build.nokogiri --use-system-libraries

COPY Gemfile Gemfile.lock ./

RUN bundle config set without 'production'
RUN bundle install

COPY . .

CMD ["./docker/invoke.sh"]
