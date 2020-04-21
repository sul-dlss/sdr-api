# frozen_string_literal: true

server 'sdr-api-qa.stanford.edu', user: 'sdr', roles: %w[app db web]

Capistrano::OneTimeKey.generate_one_time_key!
