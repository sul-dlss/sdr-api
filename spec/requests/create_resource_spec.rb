# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Create a resource' do
  let(:request) do
    <<~JSON
      {
        "type":"#{type_uri}",
        "label":"hello",
        "access": {
          "copyright":"All rights reserved unless otherwise indicated.",
          "useAndReproductionStatement":"Property rights reside with the repository...",
          "embargo": {
            "releaseDate": "2029-06-22T07:00:00.000+00:00",
            "access": "world"
          }
        },
        "administrative": {
          "hasAdminPolicy":"druid:bc123df4567"
        },
        "identification": {
          "catalogLinks": [
              {
                "catalog":"symphony",
                "catalogRecordId":"123456"
              }
          ],
          "sourceId":"googlebooks:stanford_82323429"
        },
        #{structural}
      }
    JSON
  end

  let(:structural) do
    <<~JSON
      "structural":{
        "isMemberOf":"druid:fg123hj4567",
        "contains":[
          {
            "type":"http://cocina.sul.stanford.edu/models/fileset.jsonld",
            "label":"Page 1",
            "structural":{
              "contains":[
                {
                  "type":"http://cocina.sul.stanford.edu/models/file.jsonld",
                  "filename":"file2.txt",
                  "label":"file2.txt",
                  "hasMessageDigests":[
                    {"type":"md5","digest":"7f99d78a78a233ebbf81ec5b364380fc"},
                    {"type":"sha1","digest":"c65f99f8c5376adadddc46d5cbcf5762f9e55eb7"}
                  ],
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
    JSON
  end

  let(:response_body) do
    <<~JSON
      {
        "externalIdentifier":"druid:abc123",
        "version":1,
        "type":"#{type_uri}",
        "label":"hello",
        "access": {
          "embargo": {
            "releaseDate": "2029-06-22T07:00:00.000+00:00",
            "access": "world"
          }
        },
        "administrative": {
          "hasAdminPolicy":"druid:bc123df4567"
        },
        "identification": {
          "sourceId":"googlebooks:stanford_82323429",
          "catalogLinks": [
            {
              "catalog":"symphony",
              "catalogRecordId":"123456"
            }
          ]
        },
        "structural":{
          "isMemberOf":"druid:fg123hj4567",
          "contains":[
            {
              "type":"http://cocina.sul.stanford.edu/models/fileset.jsonld",
              "label":"Page 1",
              "version":1,
              "externalIdentifier":"abc123-1",
              "structural":{
                "contains":[
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
                    },
                    "version":1
                  }
                ]
              }
            }
          ]
        }
      }
    JSON
  end

  let(:workflow_client) { instance_double(Dor::Workflow::Client, create_workflow_by_name: nil) }
  let(:blob) do
    instance_double(ActiveStorage::Blob, byte_size: 26_659,
                                         checksum: 'f5nXiniiM+u/gexbNkOA/A==',
                                         content_type: 'text/plain')
  end

  before do
    allow(ActiveStorage::Blob).to receive(:find).and_return(blob)
    allow(Dor::Workflow::Client).to receive(:new).and_return(workflow_client)
  end

  context 'with an image resource' do
    let(:type_uri) { Cocina::Models::Vocab.image }

    context 'when the registration request is successful' do
      before do
        # rubocop:disable Layout/LineLength
        stub_request(:post, 'http://localhost:3003/v1/objects')
          .with(
            body: '{"type":"http://cocina.sul.stanford.edu/models/image.jsonld","label":"hello","version":1,"access":{"embargo":{"releaseDate":"2029-06-22T07:00:00.000+00:00","access":"world"},"access":"dark","copyright":"All rights reserved unless otherwise indicated.","useAndReproductionStatement":"Property rights reside with the repository..."},"administrative":{"releaseTags":[],"hasAdminPolicy":"druid:bc123df4567"},"identification":{"sourceId":"googlebooks:stanford_82323429","catalogLinks":[{"catalog":"symphony","catalogRecordId":"123456"}]},"structural":{"contains":[{"type":"http://cocina.sul.stanford.edu/models/fileset.jsonld","label":"Page 1","version":1,"identification":{},"structural":{"contains":[{"access":{"access":"citation-only"},"administrative":{"sdrPreserve":true,"shelve":true},"type":"http://cocina.sul.stanford.edu/models/file.jsonld","label":"file2.txt","filename":"file2.txt","size":26659,"hasMessageDigests":[{"type":"md5","digest":"7f99d78a78a233ebbf81ec5b364380fc"},{"type":"sha1","digest":"c65f99f8c5376adadddc46d5cbcf5762f9e55eb7"}],"hasMimeType":"text/plain","version":1}]}}],"isMemberOf":"druid:fg123hj4567"}}',
            headers: {
              'Accept' => 'application/json',
              'Authorization' => 'Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJGb28ifQ.-BVfLTW9Q1_ZQEsGv4tuzGLs5rESN7LgdtEwUltnKv4',
              'Content-Type' => 'application/json'
            }
          )
          .to_return(status: 200, body: response_body, headers: {})
        # rubocop:enable Layout/LineLength

        allow(IngestJob).to receive(:perform_later)
      end

      it 'registers the resource and kicks off IngestJob' do
        post '/v1/resources',
             params: request,
             headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{jwt}" }

        expect(response).to be_created
        expect(JSON.parse(response.body)['druid']).to be_present
        expect(IngestJob).to have_received(:perform_later)
        expect(workflow_client).to have_received(:create_workflow_by_name).with('druid:abc123',
                                                                                'registrationWF', version: 1)
      end
    end
  end

  context 'with a book resource' do
    let(:type_uri) { Cocina::Models::Vocab.book }

    context 'when the registration request is successful' do
      before do
        # rubocop:disable Layout/LineLength
        stub_request(:post, 'http://localhost:3003/v1/objects')
          .with(
            body: '{"type":"http://cocina.sul.stanford.edu/models/book.jsonld","label":"hello","version":1,"access":{"embargo":{"releaseDate":"2029-06-22T07:00:00.000+00:00","access":"world"},"access":"dark","copyright":"All rights reserved unless otherwise indicated.","useAndReproductionStatement":"Property rights reside with the repository..."},"administrative":{"releaseTags":[],"hasAdminPolicy":"druid:bc123df4567"},"identification":{"sourceId":"googlebooks:stanford_82323429","catalogLinks":[{"catalog":"symphony","catalogRecordId":"123456"}]},"structural":{"contains":[{"type":"http://cocina.sul.stanford.edu/models/fileset.jsonld","label":"Page 1","version":1,"identification":{},"structural":{"contains":[{"access":{"access":"citation-only"},"administrative":{"sdrPreserve":true,"shelve":true},"type":"http://cocina.sul.stanford.edu/models/file.jsonld","label":"file2.txt","filename":"file2.txt","size":26659,"hasMessageDigests":[{"type":"md5","digest":"7f99d78a78a233ebbf81ec5b364380fc"},{"type":"sha1","digest":"c65f99f8c5376adadddc46d5cbcf5762f9e55eb7"}],"hasMimeType":"text/plain","version":1}]}}],"isMemberOf":"druid:fg123hj4567"}}',
            headers: {
              'Accept' => 'application/json',
              'Authorization' => 'Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJGb28ifQ.-BVfLTW9Q1_ZQEsGv4tuzGLs5rESN7LgdtEwUltnKv4',
              'Content-Type' => 'application/json'
            }
          )
          .to_return(status: 200, body: response_body, headers: {})
        # rubocop:enable Layout/LineLength

        allow(IngestJob).to receive(:perform_later)
      end

      it 'registers the resource and kicks off IngestJob' do
        post '/v1/resources',
             params: request,
             headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{jwt}" }

        expect(response).to be_created
        expect(JSON.parse(response.body)['druid']).to be_present
        expect(IngestJob).to have_received(:perform_later)
        expect(workflow_client).to have_received(:create_workflow_by_name).with('druid:abc123',
                                                                                'registrationWF', version: 1)
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

    context 'when the registration request unexpectedly fails' do
      before do
        allow(Dor::Services::Client.objects).to receive(:register)
          .and_raise(Dor::Services::Client::UnexpectedResponse,
                     "Conflict: 409 (An object with the source ID 'abcd:1234' already registered)")
      end

      let(:error) { JSON.parse(response.body)['errors'][0] }

      it 'returns an error response' do
        post '/v1/resources',
             params: request,
             headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{jwt}" }
        expect(response).to have_http_status('409')
        expect(error['status']).to eq '409'
      end
    end

    context 'when the create registrationWF request fails' do
      before do
        # rubocop:disable Layout/LineLength
        stub_request(:post, 'http://localhost:3003/v1/objects')
          .with(
            body: '{"type":"http://cocina.sul.stanford.edu/models/book.jsonld","label":"hello","version":1,"access":{"embargo":{"releaseDate":"2029-06-22T07:00:00.000+00:00","access":"world"},"access":"dark","copyright":"All rights reserved unless otherwise indicated.","useAndReproductionStatement":"Property rights reside with the repository..."},"administrative":{"releaseTags":[],"hasAdminPolicy":"druid:bc123df4567"},"identification":{"sourceId":"googlebooks:stanford_82323429","catalogLinks":[{"catalog":"symphony","catalogRecordId":"123456"}]},"structural":{"contains":[{"type":"http://cocina.sul.stanford.edu/models/fileset.jsonld","label":"Page 1","version":1,"identification":{},"structural":{"contains":[{"access":{"access":"citation-only"},"administrative":{"sdrPreserve":true,"shelve":true},"type":"http://cocina.sul.stanford.edu/models/file.jsonld","label":"file2.txt","filename":"file2.txt","size":26659,"hasMessageDigests":[{"type":"md5","digest":"7f99d78a78a233ebbf81ec5b364380fc"},{"type":"sha1","digest":"c65f99f8c5376adadddc46d5cbcf5762f9e55eb7"}],"hasMimeType":"text/plain","version":1}]}}],"isMemberOf":"druid:fg123hj4567"}}',
            headers: {
              'Accept' => 'application/json',
              'Authorization' => 'Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJGb28ifQ.-BVfLTW9Q1_ZQEsGv4tuzGLs5rESN7LgdtEwUltnKv4',
              'Content-Type' => 'application/json'
            }
          )
          .to_return(status: 200, body: response_body, headers: {})
        # rubocop:enable Layout/LineLength

        allow(workflow_client).to receive(:create_workflow_by_name).and_raise(Dor::WorkflowException, 'broken')
      end

      let(:error) { JSON.parse(response.body)['errors'][0] }

      it 'returns an error response' do
        post '/v1/resources',
             params: request,
             headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{jwt}" }
        expect(response).to have_http_status('502')
        expect(error['title']).to eq 'Error creating registrationWF with workflow-service'
        expect(error['detail']).to eq 'broken'
      end
    end
  end

  context 'without any files' do
    let(:type_uri) { Cocina::Models::Vocab.object }
    let(:structural) { '"structural":{"isMemberOf":"druid:fg123hj4567"}' }

    context 'when the registration request is successful' do
      before do
        # rubocop:disable Layout/LineLength
        stub_request(:post, 'http://localhost:3003/v1/objects')
          .with(
            body: '{"type":"http://cocina.sul.stanford.edu/models/object.jsonld","label":"hello","version":1,"access":{"embargo":{"releaseDate":"2029-06-22T07:00:00.000+00:00","access":"world"},"access":"dark","copyright":"All rights reserved unless otherwise indicated.","useAndReproductionStatement":"Property rights reside with the repository..."},"administrative":{"releaseTags":[],"hasAdminPolicy":"druid:bc123df4567"},"identification":{"sourceId":"googlebooks:stanford_82323429","catalogLinks":[{"catalog":"symphony","catalogRecordId":"123456"}]},"structural":{"isMemberOf":"druid:fg123hj4567"}}',
            headers: {
              'Accept' => 'application/json',
              'Authorization' => 'Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJGb28ifQ.-BVfLTW9Q1_ZQEsGv4tuzGLs5rESN7LgdtEwUltnKv4',
              'Content-Type' => 'application/json'
            }
          )
          .to_return(status: 200, body: response_body, headers: {})
        # rubocop:enable Layout/LineLength

        allow(IngestJob).to receive(:perform_later)
      end

      it 'registers the resource and kicks off IngestJob' do
        post '/v1/resources',
             params: request,
             headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{jwt}" }
        expect(response).to be_created
        expect(JSON.parse(response.body)['druid']).to be_present
        expect(IngestJob).to have_received(:perform_later)
        expect(workflow_client).to have_received(:create_workflow_by_name).with('druid:abc123',
                                                                                'registrationWF', version: 1)
      end
    end
  end
end
