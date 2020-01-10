# frozen_string_literal: true

module AuthHelper
  def jwt
    JsonWebToken.encode(payload)
  end

  private

  def payload
    user = User.create!(email: 'jcoyne85@stanford.edu', password: 'sekr3t!')

    { user_id: user.id }
  end
end
