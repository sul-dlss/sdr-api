# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccountPolicy, type: :policy do
  # See https://actionpolicy.evilmartians.io/#/testing?id=rspec-dsl
  let(:user) { build_stubbed :user }
  let(:context) { { user: user } }

  describe_rule :proxy? do
    succeed 'when the user is argo' do
      before { user.email = Settings.argo_user }
    end

    failed 'when user is not argo'
  end
end
