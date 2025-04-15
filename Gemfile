# frozen_string_literal: true

source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

gem 'action_policy'
gem 'amazing_print'
gem 'bcrypt', '~> 3.1.7' # Use Active Model has_secure_password
gem 'bootsnap', '>= 1.4.2', require: false # Reduces boot times through caching; required in config/boot.rb
gem 'cocina-models', '~> 0.101.0'
gem 'committee'
gem 'config', '~> 2.0'
gem 'dor-services-client', '~> 15.6'
gem 'dor-workflow-client', '~> 7.0'
gem 'druid-tools'
gem 'honeybadger'
gem 'jbuilder', '~> 2.7' # Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'jwt' # JSON web tokens (for authentication)
gem 'lograge'
gem 'marcel'
gem 'okcomputer'
gem 'pg' # Postgres database client
gem 'rails', '~> 7.2.0'
gem 'sidekiq', '~> 7.1' # background job processing
gem 'whenever', require: false # schedule crons

group :development, :test do
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'byebug', platforms: %i[mri mingw x64_mingw]
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
