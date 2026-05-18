# frozen_string_literal: true

# Helps with JWT-based authentication in specs
module AuthHelper
  def jwt
    JWT.encode(payload, Settings.sdr_api.hmac_secret, 'HS256')
  end

  private

  def payload
    { sub: 'sdr-api' }
  end
end
