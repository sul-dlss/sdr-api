# frozen_string_literal: true

source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

gem 'action_policy'
gem 'amazing_print'
gem 'bcrypt' # Use Active Model has_secure_password
gem 'bootsnap', require: false # Reduces boot times through caching; required in config/boot.rb
gem 'cocina-models'
gem 'committee'
gem 'config'
gem 'dor-services-client'
gem 'druid-tools'
gem 'honeybadger'
gem 'jbuilder' # Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'json_schemer-rails'
gem 'jwt' # JSON web tokens (for authentication)
gem 'lograge'
gem 'marcel'
gem 'okcomputer'
gem 'pg' # Postgres database client
gem 'rails', '~> 8.1.0'
gem 'sidekiq' # background job processing
gem 'whenever', require: false # schedule crons

group :development, :test do
  # Security audit for known security defects in code (use config/brakeman.ignore to ignore issues)
  gem 'brakeman', require: false
  # Call 'debugger' anywhere in the code to stop execution and get a debug console
  gem 'debug'
  gem 'equivalent-xml'
  gem 'factory_bot_rails'
  gem 'rspec_junit_formatter'
  gem 'rspec-rails'
  gem 'rubocop'
  gem 'rubocop-capybara'
  gem 'rubocop-factory_bot'
  gem 'rubocop-rails'
  gem 'rubocop-rspec'
  gem 'rubocop-rspec_rails'
  gem 'simplecov', require: false
  gem 'webmock'
end

group :development do
  gem 'puma' # Use Puma as the app server
end

group :deployment do
  gem 'capistrano-passenger', require: false
  gem 'capistrano-rails', require: false
  gem 'dlss-capistrano', require: false
end
