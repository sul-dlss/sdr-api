# frozen_string_literal: true

class AuthenticationController < ApplicationController
  before_action :authorize_request, except: :login

  # POST /auth/login
  def login
    @user = User.find_by_email(params[:email])
    if @user&.authenticate(params[:password])
      exp = Time.now + 24.hours.to_i
      token = JsonWebToken.encode({ user_id: @user.id }, exp)
      render json: { token: token, exp: exp.strftime('%m-%d-%Y %H:%M') }, status: :ok
    else
      render json: { error: 'unauthorized' }, status: :unauthorized
    end
  end
end
