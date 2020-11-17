# frozen_string_literal: true

# A policy to govern access to resources
class ResourcePolicy < ApplicationPolicy
  # See https://actionpolicy.evilmartians.io/#/writing_policies

  # Any use with an account can create or update resources
  def create?
    true
  end

  alias_rule :update?, to: :create?
end
