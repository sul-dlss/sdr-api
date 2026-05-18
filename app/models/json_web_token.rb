# frozen_string_literal: true

class JsonWebToken
  def self.encode(payload, exp = 24.hours.from_now)
    payload[:exp] = exp.to_i
    JWT.encode(payload, Settings.sdr_api.hmac_secret)
  end

  def self.decode(token)
    decoded = JWT.decode(token, Settings.sdr_api.hmac_secret)[0]
    ActiveSupport::HashWithIndifferentAccess.new decoded
  end
end
