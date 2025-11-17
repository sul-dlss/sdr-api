# frozen_string_literal: true

class ApplicationController < ActionController::API
  include RequestAuthorization
  include ActionPolicy::Controller

  authorize :user, through: :current_user

  rescue_from(ActionPolicy::Unauthorized) do |_exp|
    render json: { error: 'Not Authorized' }, status: :unauthorized
  end
end
