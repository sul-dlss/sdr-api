# frozen_string_literal: true

# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

require_relative 'config/application'

Rails.application.load_tasks

begin
  require 'rspec/core/rake_task'
  require 'rubocop/rake_task'

  desc 'Run linter and tests'
  task ci: %i[rubocop spec]
rescue LoadError
  puts 'gems rspec and rubocop not available presumably b/c this is a production environment'
end

task default: :ci
