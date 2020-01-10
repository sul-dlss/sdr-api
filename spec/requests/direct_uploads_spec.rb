# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Direct upload' do
  let(:json) do
    '{"blob":{"filename":"Gemfile.lock","byte_size":1751,"checksum":"vQ0xN+GwJBg9iEAcD4v73g==",' \
    '"content_type":"text/html"}}'
  end

  context 'when unauthorized' do
    it 'returns 401' do
      post '/v1/direct_uploads',
           params: json,
           headers: { 'Content-Type' => 'application/json' }
      expect(response).to be_unauthorized
    end
  end

  context 'when authorized' do
    it 'returns 200' do
      post '/v1/direct_uploads',
           params: json,
           headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{jwt}" }
      expect(response).to be_successful
    end
  end
end
