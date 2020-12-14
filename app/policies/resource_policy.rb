# frozen_string_literal: true

# A policy to govern access to resources
class ResourcePolicy < ApplicationPolicy
  # See https://actionpolicy.evilmartians.io/#/writing_policies

  # Any user with an account can create or update resources
  def create?
    true
  end

  # Any user with an account can read the resources
  # TODO: We should add restrictions like Argo does:
  #   A user in the admin group or workgroup:sdr:viewer-role
  #   or the APO for this item has one of the users groups set for the dor-apo-manager role
  def show?
    true
  end

  alias_rule :update?, to: :create?
end
