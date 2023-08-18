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
require_relative 'environment'

job_type :runner_hb,
         "cd :path && bin/rails runner -e :environment ':task' " \
         "&& curl 'https://api.honeybadger.io/v1/check_in/:check_in' :output"

every :day do
  set :output, standard: 'log/uploads_sweeper.log', error: 'log/uploads_sweeper.error.log'
  set :check_in, Settings.honeybadger_checkins.direct_uploads_sweeper
  runner_hb 'DirectUploadsSweeper.new(strategy: SelectOutdatedUploadsStrategy).sweep'
end
