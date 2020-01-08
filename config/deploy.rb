# frozen_string_literal: true

set :application, 'sdr-api'
set :repo_url, 'https://github.com/sul-dlss/repository-api.git'

# Default branch is :master
ask :branch, proc { `git rev-parse --abbrev-ref HEAD`.chomp }.call

# Default deploy_to directory is /var/www/my_app_name
set :deploy_to, '/opt/app/sdr/sdr-api'

# Default value for :format is :airbrussh.
# set :format, :airbrussh

# You can configure the Airbrussh format using :format_options.
# These are the defaults.
# set :format_options, command_output: true, log_file: 'log/capistrano.log', color: :auto, truncate: :auto

# Default value for :pty is false
# set :pty, true

# Default value for :linked_files is []
append :linked_files, %w[config/database.yml config/honeybadger.yml config/secrets.yml]

# Default value for linked_dirs is []
append :linked_dirs, %w[log config/settings public/system vendor/bundle]

# Default value for default_env is {}
# set :default_env, { path: '/opt/ruby/bin:$PATH' }

# Default value for local_user is ENV['USER']
# set :local_user, -> { `git config user.name`.chomp }

# Default value for keep_releases is 5
# set :keep_releases, 5

# Uncomment the following to require manually verifying the host key before first deploy.
# set :ssh_options, verify_host_key: :secure

# Honeybadger will otherwise default to `Rails.env`
set :honeybadger_env, fetch(:stage)

# Update shared_configs as part of deployment process
before 'deploy:restart', 'shared_configs:update'
