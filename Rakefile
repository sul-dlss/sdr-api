# frozen_string_literal: true

# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

require_relative 'config/application'

Rails.application.load_tasks

# clear the default task injected by rspec
task(:default).clear

# and replace it with our own
task default: :ci

begin
  require 'rspec/core/rake_task'
rescue LoadError
  puts 'gem rspec not available presumably b/c this is a production environment'
end

begin
  require 'rubocop/rake_task'

  RuboCop::RakeTask.new
rescue LoadError
  puts 'gem rubocop not available presumably b/c this is a production environment'
end

desc 'Run Continuous Integration Suite (linter and tests)'
task ci: %i[rubocop db:migrate spec]
