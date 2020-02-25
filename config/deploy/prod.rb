# frozen_string_literal: true

server 'sdr-api-prod.stanford.edu', user: 'sdr', roles: %w[app db web]

Capistrano::OneTimeKey.generate_one_time_key!
set :rails_env, 'production'
set :bundle_without, %w[deployment test development].join(' ')
