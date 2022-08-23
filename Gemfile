# frozen_string_literal: true

source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '~> 7.0.3'
# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'jbuilder', '~> 2.7'

# Use Active Model has_secure_password
gem 'bcrypt', '~> 3.1.7'

# JSON web tokens (for authentication)
gem 'jwt'
# Postgres database client
gem 'pg'
# Reduces boot times through caching; required in config/boot.rb
gem 'bootsnap', '>= 1.4.2', require: false

gem 'action_policy'
gem 'assembly-objectfile', '~> 2.0'
gem 'cocina-models', '~> 0.84.0'
gem 'committee'
gem 'config', '~> 2.0'
gem 'dor-services-client', '~> 12.0'
gem 'dor-workflow-client', '~> 5.0'
gem 'druid-tools'
gem 'honeybadger'
gem 'lograge'
gem 'okcomputer'
gem 'sidekiq', '~> 6.0'
gem 'sidekiq-statistic'
gem 'whenever', require: false

group :development, :test do
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'byebug', platforms: %i[mri mingw x64_mingw]
  gem 'equivalent-xml'
  gem 'factory_bot_rails'
  gem 'rspec_junit_formatter'
  gem 'rspec-rails'
  gem 'rubocop'
  gem 'rubocop-rails'
  gem 'rubocop-rspec'
  gem 'simplecov', require: false
  gem 'webmock'
end

group :development do
  # Use Puma as the app server
  gem 'puma', '~> 5.6'
end

group :deployment do
  gem 'capistrano-passenger', require: false
  gem 'capistrano-rails', require: false
  gem 'capistrano-rvm', require: false
  gem 'dlss-capistrano', require: false
end
