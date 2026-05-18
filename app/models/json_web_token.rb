# frozen_string_literal: true

class JsonWebToken
  def self.encode(payload, exp = 24.hours.from_now)
    payload[:exp] = exp.to_i
    JWT.encode(payload, Settings.sdr_api.hmac_secret, 'HS256')
  end

  def self.decode(token)
    decoded = JWT.decode(token, Settings.sdr_api.hmac_secret, true, { algorithm: 'HS256' })[0]
    ActiveSupport::HashWithIndifferentAccess.new decoded
  end
end
