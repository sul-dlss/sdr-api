# frozen_string_literal: true

source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '~> 6.0.1'
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

gem 'assembly-objectfile'
gem 'committee'
gem 'config', '~> 2.0'
gem 'dor-services-client'
gem 'dor-workflow-client'
gem 'druid-tools'
gem 'honeybadger'
gem 'okcomputer'
gem 'sidekiq', '~> 5.2'
gem 'sidekiq-statistic'

group :development, :test do
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'byebug', platforms: %i[mri mingw x64_mingw]
  gem 'factory_bot_rails'
  gem 'rspec-rails'
  gem 'rubocop'
  gem 'rubocop-rspec'
  gem 'simplecov', require: false
  gem 'webmock'
end

group :development do
  gem 'listen', '>= 3.0.5', '< 3.2'
  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  # Use Puma as the app server
  gem 'puma', '~> 4.1'
  gem 'spring'
  gem 'spring-watcher-listen', '~> 2.0.0'
end

group :deployment do
  gem 'capistrano-passenger', require: false
  gem 'capistrano-rails', require: false
  gem 'capistrano-sidekiq', require: false
  gem 'dlss-capistrano', require: false
end
