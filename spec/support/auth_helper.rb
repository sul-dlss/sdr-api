# frozen_string_literal: true

module AuthHelper
  def jwt(user = create(:user))
    JsonWebToken.encode(create_payload(user))
  end

  private

  def create_payload(user)
    { user_id: user.id }
  end
end
