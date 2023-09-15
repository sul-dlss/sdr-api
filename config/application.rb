# frozen_string_literal: true

require_relative 'boot'

require 'rails'
# Pick the frameworks you want:
require 'active_model/railtie'
require 'active_job/railtie'
require 'active_record/railtie'
require 'active_storage/engine'
require 'action_controller/railtie'
# require "action_mailer/railtie"
# require "action_mailbox/engine"
# require "action_text/engine"
require 'action_view/railtie'
# require "action_cable/engine"
# require "sprockets/railtie"
# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module SdrApi
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.0

    # accept_request_filter omits OKComputer and Sidekiq
    accept_proc = proc { |request| request.path.start_with?('/v1') }
    config.middleware.use(
      Committee::Middleware::RequestValidation,
      schema_path: 'openapi.yml',
      strict: true,
      accept_request_filter: accept_proc,
      query_hash_key: 'action_dispatch.request.query_parameters', # hush committee deprecation warning
      parameter_overwite_by_rails_rule: false,
      strict_reference_validation: true
    )
    config.middleware.use(
      Committee::Middleware::ResponseValidation,
      schema_path: 'openapi.yml',
      parse_response_by_content_type: false, # hush committee deprecation warning
      query_hash_key: 'action_dispatch.request.query_parameters', # hush committee deprecation warning
      parameter_overwite_by_rails_rule: false,
      strict_reference_validation: true
    )

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration can go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded after loading
    # the framework and any gems in your application.

    # Only loads a smaller set of middleware suitable for API only apps.
    # Middleware like session, flash, cookies can be added back manually.
    # Skip views, helpers and assets when generating a new resource.
    config.api_only = true

    # Until https://github.com/rails/rails/pull/32238 is resolved
    config.action_controller.allow_forgery_protection = false

    # This makes sure our Postgres enums function are persisted to the schema
    config.active_record.schema_format = :sql

    # turn off drawing of Active Storage's default routes, we'll add the ones we want
    config.active_storage.draw_routes = false

    # Override the default (5.minutes), so that large files have enough time to upload
    config.active_storage.service_urls_expire_in = 20.minutes

    # Set up a session store so we can access the Sidekiq Web UI
    # See: https://github.com/mperham/sidekiq/wiki/Monitoring#rails-api-application-session-configuration
    config.session_store :cookie_store, key: '_sdr-api_session'
  end
end
