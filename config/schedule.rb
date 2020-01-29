# frozen_string_literal: true

# Use this file to easily define all of your cron jobs.
#
# It's helpful, but not entirely necessary to understand cron before proceeding.
# https://en.wikipedia.org/wiki/Cron

# Example:
#
# set :output, "/path/to/my/cron_log.log"
#
# Learn more: https://github.com/javan/whenever

every :day do
  set :output, standard: nil, error: 'log/uploads_sweeper.log'
  runner 'DirectUploadsSweeper.new(strategy: SelectOutdatedUploadsStrategy).sweep'
end
