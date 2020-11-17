# frozen_string_literal: true

# This has methods for doing bearer auth with a JWT
module RequestAuthorization
  extend ActiveSupport::Concern

  def authorize_request
    header = request.headers['Authorization']
    header = header.split(' ').last if header
    begin
      decoded = JsonWebToken.decode(header)
      @current_user = User.find(decoded[:user_id])
    rescue ActiveRecord::RecordNotFound, JWT::DecodeError => e
      render json: { errors: e.message }, status: :unauthorized
    end
  end

  included do
    attr_reader :current_user
  end
end
