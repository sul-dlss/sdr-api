# frozen_string_literal: true

# A policy to govern access to resources
class ResourcePolicy < ApplicationPolicy
  # See https://actionpolicy.evilmartians.io/#/writing_policies

  # Any user with an account can create or update resources
  def create?
    return false unless user.active?
    return true if user.full_access?

    # Collection-limited users can only update DROs
    return false unless record.dro?

    # But those DROs must be member of one of the user's collections
    user.collections.intersect?(record.structural.isMemberOf)
  end

  # Any user with an account can read the resources
  # TODO: We should add restrictions like Argo does:
  #   A user in the admin group or workgroup:sdr:viewer-role
  #   or the APO for this item has one of the users groups set for the dor-apo-manager role
  def show?
    user.active?
  end

  alias_rule :update?, to: :create?
end
