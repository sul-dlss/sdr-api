# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Proxy Authorization' do
  let(:to) do
    create(:user, email: 'jcoyne85@stanford.edu')
  end

  before do
    post "/v1/auth/proxy?to=#{to.email}",
         headers: { 'Authorization' => "Bearer #{jwt(as)}" }
  end

  context 'when the requestor is authorized' do
    let(:as) do
      create(:user, email: 'argo@dlss.sul.stanford.edu')
    end

    it 'grants a token for the proxied user' do
      expect(JSON.parse(response.body)['token']).to be_present
      expect(response).to be_ok
    end
  end

  context 'when the requestor is not authorized' do
    let(:as) do
      create(:user, email: 'joe@dlss.sul.stanford.edu')
    end

    it 'returns unauthorized' do
      expect(response).to be_unauthorized
    end
  end
end
