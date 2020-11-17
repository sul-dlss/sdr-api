# frozen_string_literal: true

require 'sidekiq/web'

Rails.application.routes.draw do
  scope 'v1' do
    post '/auth/login', to: 'authentication#login'
    post '/auth/proxy', to: 'authentication#proxy'

    resources :resources, only: %i[create update]
    resources :background_job_results, only: [:show], defaults: { format: :json }

    # We don't need all of the activestorage routes, just these few:
    get  '/disk/:encoded_key/*filename' => 'active_storage/disk#show', as: :rails_disk_service
    put  '/disk/:encoded_token' => 'active_storage/disk#update', as: :update_rails_disk_service
    post '/direct_uploads' => 'direct_uploads#create', as: :rails_direct_uploads
  end
  mount Sidekiq::Web => '/queues'
end
