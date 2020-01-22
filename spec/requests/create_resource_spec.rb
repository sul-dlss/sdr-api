# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Create a resource' do
  let(:request) do
    <<~JSON
      {
        "type":"http://cocina.sul.stanford.edu/models/book.jsonld",
        "label":"hello",
        "access": {},
        "administrative": {
          "hasAdminPolicy":"druid:bc123df4567"
        },
        "identification": {
          "catkey":"123456",
          "sourceId":"googlebooks:stanford_82323429"
        },
        "structural":{
          "isMemberOf":"druid:fg123hj4567",
          "hasMember":[
            {
              "type":"http://cocina.sul.stanford.edu/models/fileset.jsonld",
              "label":"Page 1",
              "structural":{
                "hasMember":[
                  {
                    "type":"http://cocina.sul.stanford.edu/models/file.jsonld",
                    "filename":"file2.txt",
                    "label":"file2.txt",
                    "externalIdentifier":"eyJfcmFpbHMiOnsibWVzc2FnZSI6IkJBaHBOZz09IiwiZXhwIjpudWxsLCJwdXIiOiJibG9iX2lkIn19--89b7b484c80fe7f94d4aeff21c0c0e3e037d5c03",
                    "administrative":{
                      "sdrPreserve":true,
                      "shelve":true
                    },
                    "access": {
                      "access":"citation-only"
                    }
                  }
                ]
              }
            }
          ]
        }
      }
    JSON
  end

  context 'when the registration request is successful' do
    before do
      # rubocop:disable Layout/LineLength
      stub_request(:post, 'http://localhost:3003/v1/objects')
        .with(
          body: '{"object_type":"item","admin_policy":"druid:bc123df4567","label":"hello",' \
                '"metadata_source":"label","other_id":"symphony:123456","collection":"druid:fg123hj4567"}',
          headers: {
            'Accept' => 'application/json',
            'Authorization' => 'Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJGb28ifQ.-BVfLTW9Q1_ZQEsGv4tuzGLs5rESN7LgdtEwUltnKv4',
            'Content-Type' => 'application/json'
          }
        )
        .to_return(status: 200, body: '{"pid":"druid:abc123"}', headers: {})
      # rubocop:enable Layout/LineLength

      stub_request(:post, 'http://localhost:3001/objects/druid:abc123/workflows/accessionWF?lane-id=default')
        .to_return(status: 200, body: '', headers: {})

      allow(IngestJob).to receive(:perform_later)
    end

    it 'Registers the resource and kicks off accessionWF' do
      post '/v1/resources',
           params: request,
           headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{jwt}" }

      expect(response).to be_created
      expect(JSON.parse(response.body)['druid']).to be_present
      expect(IngestJob).to have_received(:perform_later)
    end
  end

  context 'when the registration request is unsuccessful' do
    before do
      stub_request(:post, 'http://localhost:3003/v1/objects')
        .to_return(status: [400, 'Bad Request'],
                   body: "Unable to find 'druid:bk123gh4567' in fedora. See logger for details")
    end

    let(:error) { JSON.parse(response.body)['errors'][0] }

    it 'returns an error response' do
      post '/v1/resources',
           params: request,
           headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{jwt}" }
      expect(response).to have_http_status(:bad_request)
      expect(error['title']).to eq 'Bad Request'
      expect(error['detail']).to eq "Bad Request: 400 (Unable to find 'druid:bk123gh4567' " \
        'in fedora. See logger for details)'
    end
  end

  context 'when the registration request fails' do
    before do
      allow(Dor::Services::Client.objects).to receive(:register)
        .and_raise(Dor::Services::Client::ConnectionFailed, 'broken')
    end

    let(:error) { JSON.parse(response.body)['errors'][0] }

    it 'returns an error response' do
      post '/v1/resources',
           params: request,
           headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{jwt}" }
      expect(response).to have_http_status(:gateway_timeout)
      expect(error['title']).to eq 'Unable to reach dor-services-app'
      expect(error['detail']).to eq 'broken'
    end
  end
end
