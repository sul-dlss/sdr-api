# frozen_string_literal: true

# A policy to govern access to other accounts
class AccountPolicy < ApplicationPolicy
  # Only argo should be allowed to proxy to other users
  def proxy?
    user.email == Settings.argo_user
  end
end
