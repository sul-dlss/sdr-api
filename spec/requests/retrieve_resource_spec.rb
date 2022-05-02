# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Retrieve a resource' do
  context 'when happy path' do
    let(:request) { build(:dro, id: 'druid:bc999dg9999').to_json }

    before do
      stub_request(:get, 'http://localhost:3003/v1/objects/druid:bc999dg9999')
        .to_return(status: 200, body: request, headers: {
                     'Last-Modified' => 'Wed, 03 Mar 2021 18:58:00 GMT',
                     'X-Created-At' => 'Wed, 01 Jan 2021 12:58:00 GMT',
                     'X-Served-By' => 'Awesome webserver',
                     'ETag' => 'W/"d41d8cd98f00b204e9800998ecf8427e"'
                   })
    end

    it 'returns the cocina model' do
      get '/v1/resources/druid:bc999dg9999',
          headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{jwt}" }
      expect(response).to be_successful
      expect(JSON.parse(response.body)['externalIdentifier']).to eq 'druid:bc999dg9999'
    end
  end

  context 'when dor-services-client returns an unexpected response' do
    let(:error_message) { 'Something really went wrong in DSA' }

    before do
      allow(Dor::Services::Client).to receive(:object).and_raise(
        Dor::Services::Client::UnexpectedResponse.new(response: '', errors: [{ 'title' => error_message }])
      )
    end

    it 'passes the error information along to the caller' do
      get '/v1/resources/druid:bc999dg9999',
          headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{jwt}" }
      expect(response).not_to be_successful
      expect(response).to have_http_status(:internal_server_error)
      expect(JSON.parse(response.body)['errors'].first).to include(
        'status' => '500',
        'title' => 'Internal server error',
        'detail' => "#{error_message} ()"
      )
    end
  end

  context 'when dor-services-client returns a not found response' do
    let(:error_message) { 'Object not found: druid:bc999dg9999' }

    before do
      allow(Dor::Services::Client).to receive(:object).and_raise(
        Dor::Services::Client::NotFoundResponse,
        error_message
      )
    end

    it 'passes the error information along to the caller' do
      get '/v1/resources/druid:bc999dg9999',
          headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{jwt}" }
      expect(response).not_to be_successful
      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body)['errors'].first).to include(
        'status' => '404',
        'title' => error_message,
        'detail' => error_message
      )
    end
  end
end
