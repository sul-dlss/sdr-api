# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Authorization' do
  context 'without a bearer token' do
    before do
      User.create!(email: 'jcoyne85@stanford.edu', password: 'sekr3t!')
    end

    it 'Logs tokens to honeybadger' do
      post '/v1/auth/login',
           params: { email: 'jcoyne85@stanford.edu', password: 'sekr3t!' }
      expect(JSON.parse(response.body)['token']).to be_present
      expect(response).to be_ok
    end
  end
end
