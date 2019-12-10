# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Create a resource' do
  let(:request) do
    <<~JSON
      {
        "@context":"http://cocina.sul.stanford.edu/contexts/cocina-base.jsonld",
        "@type":"book","label":"hello",
        "structural":{
          "hasMember":[
            {
              "@context":"http://cocina.sul.stanford.edu/contexts/cocina-base.jsonld",
              "@type":"http://cocina.sul.stanford.edu/models/fileset.jsonld",
              "label":"file2.txt",
              "structural":{
                "hasMember":["eyJfcmFpbHMiOnsibWVzc2FnZSI6IkJBaHBOZz09IiwiZXhwIjpudWxsLCJwdXIiOiJibG9iX2lkIn19--89b7b484c80fe7f94d4aeff21c0c0e3e037d5c03"]
              }
            }
          ]
        }
      }
    JSON
  end

  context 'when the registration request is successful' do
    before do
      stub_request(:post, 'http://localhost:3003/v1/objects')
        .with(
          body: '{"object_type":"object","admin_policy":"TODO: what policy?","label":":auto","rights":null,"metadata_source":"label"}',
          headers: {
            'Accept' => 'application/json',
            'Authorization' => 'Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJGb28ifQ.-BVfLTW9Q1_ZQEsGv4tuzGLs5rESN7LgdtEwUltnKv4',
            'Content-Type' => 'application/json'
          }
        )
        .to_return(status: 200, body: '{"pid":"druid:abc123"}', headers: {})

      stub_request(:post, 'http://localhost:3001/objects/druid:abc123/workflows/accessionWF?lane-id=default')
        .to_return(status: 200, body: '', headers: {})
    end

    it 'Registers the resource and kicks off accessionWF' do
      post '/v1/resources', params: request
      expect(JSON.parse(response.body)['druid']).to be_present
      expect(response).to be_created
    end
  end

  context 'when the registration request is unsuccessful' do
    before do
      allow(Dor::Services::Client.objects).to receive(:register).and_raise(Dor::Services::Client::ConnectionFailed, 'broken')
    end
    let(:error) { JSON.parse(response.body)['errors'][0] }

    it 'returns an error response' do
      post '/v1/resources', params: request
      expect(response).to have_http_status(:gateway_timeout)
      expect(error['title']).to eq 'Unable to reach dor-services-app'
      expect(error['detail']).to eq 'broken'
    end
  end
end
