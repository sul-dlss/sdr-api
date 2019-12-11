# frozen_string_literal: true

Rails.application.routes.draw do
  scope 'v1' do
    # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
    post '/auth/login', to: 'authentication#login'

    resources :resources, only: [:create]
    patch '/resources/:object_id/embargo', to: 'resources#show'
  end
end
