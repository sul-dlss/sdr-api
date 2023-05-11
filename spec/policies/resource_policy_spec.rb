# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ResourcePolicy, type: :policy do
  # See https://actionpolicy.evilmartians.io/#/testing?id=rspec-dsl
  let(:user) { build_stubbed(:user) }
  let(:context) { { user: } }

  describe_rule :create? do
    succeed 'when the user exists'
  end
end
