# frozen_string_literal: true

require 'sidekiq/web'

# From Sidekiq docs: https://github.com/mperham/sidekiq/wiki/Monitoring#rails-api-application-session-configuration
# Configure Sidekiq-specific session middleware
Sidekiq::Web.use ActionDispatch::Cookies
Sidekiq::Web.use Rails.application.config.session_store, Rails.application.config.session_options

Rails.application.routes.draw do
  scope 'v1' do
    post '/auth/login', to: 'authentication#login'
    post '/auth/proxy', to: 'authentication#proxy'

    resources :resources, only: %i[create update show]
    resources :background_job_results, only: [:show], defaults: { format: :json }

    # We don't need all of the activestorage routes, just these few:
    get  '/disk/:encoded_key/*filename' => 'active_storage/disk#show', as: :rails_disk_service
    put  '/disk/:encoded_token' => 'active_storage/disk#update', as: :update_rails_disk_service
    post '/direct_uploads' => 'direct_uploads#create', as: :rails_direct_uploads
  end
  mount Sidekiq::Web => '/queues'
end
