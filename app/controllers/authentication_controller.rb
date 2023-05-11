# frozen_string_literal: true

class AuthenticationController < ApplicationController
  before_action :authorize_request, except: :login

  # POST /auth/login
  def login
    @user = User.find_by(email: params[:email])
    if @user&.authenticate(params[:password])
      render json: make_token_response(@user), status: :ok
    else
      render json: { error: 'unauthorized' }, status: :unauthorized
    end
  end

  # POST /auth/proxy
  # This allows argo to retrieve the token for other users.
  # We are trusting that argo is verifying the users identity (via Shibboleth)
  # Then it can give the user their token so they can make an API call without
  # having a password in sdr-api.
  def proxy
    authorize! :account
    user = User.create_with(password: SecureRandom.urlsafe_base64)
               .find_or_create_by(email: params[:to])
    render json: make_token_response(user), status: :ok
  end

  private

  def make_token_response(user)
    exp = Time.zone.now + 24.hours.to_i
    token = JsonWebToken.encode({ user_id: user.id }, exp)
    { token:, exp: exp.strftime('%m-%d-%Y %H:%M') }
  end
end
