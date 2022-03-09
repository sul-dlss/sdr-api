# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Create a resource' do
  before do
    allow(IngestJob).to receive(:perform_later)
  end

  context 'with a Collection' do
    let(:request) do
      <<~JSON
        {
          "cocinaVersion":"#{Cocina::Models::VERSION}",
          "label":"hello",
          "version":1,
          "type":"#{Cocina::Models::ObjectType.collection}",
          "access": {
            "view":"world"
          },
          "administrative": {
            "hasAdminPolicy":"druid:bc123df4567",
            "partOfProject":"Google Books",
            "releaseTags":[]
          },
          "identification": {
            "catalogLinks": [
                {
                  "catalog":"symphony",
                  "catalogRecordId":"123456"
                }
            ]
          }
        }
      JSON
    end

    it 'registers the resource and kicks off IngestJob' do
      post '/v1/resources',
           params: request,
           headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{jwt}" }
      expect(response).to be_created
      expect(response.location).to be_present
      expect(JSON.parse(response.body)['jobId']).to be_present
      expect(IngestJob).to have_received(:perform_later).with(model_params: JSON.parse(request),
                                                              background_job_result: instance_of(BackgroundJobResult),
                                                              signed_ids: [],
                                                              start_workflow: false,
                                                              assign_doi: false)
    end
  end

  context 'with a DRO' do
    let(:request) do
      <<~JSON
        {
          "cocinaVersion":"#{Cocina::Models::VERSION}",
          "label":"hello",
          "version":1,
          "type":"#{Cocina::Models::ObjectType.book}",
          "access": {
            "view":"world",
            "copyright":"All rights reserved unless otherwise indicated.",
            "download":"none",
            "useAndReproductionStatement":"Property rights reside with the repository...",
            "embargo": {
              "releaseDate": "2029-06-22T07:00:00.000+00:00",
              "view": "world",
              "download":"world",
              "useAndReproductionStatement": "Whatever you want"
            }
          },
          "administrative": {
            "hasAdminPolicy":"druid:bc123df4567",
            "partOfProject":"Google Books",
            "releaseTags":[]
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
          "isMemberOf":["druid:fg123hj4567"],
          "contains":[
            {
              "type":"#{Cocina::Models::FileSetType.file}",
              "label":"Page 1",
              "structural":{
                "contains":[
                  {
                    "type":"#{Cocina::Models::ObjectType.file}",
                    "filename":"file2.txt",
                    "label":"file2.txt",
                    "hasMessageDigests":[
                      {"type":"md5","digest":"7f99d78a78a233ebbf81ec5b364380fc"},
                      {"type":"sha1","digest":"c65f99f8c5376adadddc46d5cbcf5762f9e55eb7"}
                    ],
                    "externalIdentifier":"#{signed_id}",
                    "administrative":{
                      "publish":true,
                      "sdrPreserve":true,
                      "shelve":true
                    },
                    "access": {
                      "view":"stanford",
                      "download":"stanford"
                    },
                    "version":1
                  }
                ]
              },
              "version":1
            }
          ]
        }
      JSON
    end

    let(:checksum) { 'f5nXiniiM+u/gexbNkOA/A==' }

    let(:blob) do
      ActiveStorage::Blob.create!(key: 'tozuehlw6e8du20vn1xfzmiifyok',
                                  filename: 'file2.txt', byte_size: 10, checksum: checksum)
    end
    let(:signed_id) do
      ActiveStorage.verifier.generate(blob.id, purpose: :blob_id)
    end

    let(:expected_model_params) do
      model_params = Cocina::Models::RequestDRO.new(JSON.parse(request)).to_h
      file_params = model_params.dig(:structural, :contains, 0, :structural, :contains, 0)
      file_params.delete(:externalIdentifier)
      file_params[:hasMimeType] = 'application/octet-stream'
      file_params[:size] = 10
      model_params.with_indifferent_access
    end

    it 'registers the resource and kicks off IngestJob' do
      post '/v1/resources',
           params: request,
           headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{jwt}" }
      expect(response).to be_created
      expect(response.location).to be_present
      expect(JSON.parse(response.body)['jobId']).to be_present
      expect(IngestJob).to have_received(:perform_later).with(model_params: expected_model_params,
                                                              background_job_result: instance_of(BackgroundJobResult),
                                                              signed_ids: [signed_id],
                                                              start_workflow: false,
                                                              assign_doi: false)
    end

    context 'when wrong version of cocina models is supplied' do
      it 'returns 400' do
        post '/v1/resources?accession=true',
             params: request,
             headers: {
               'Content-Type' => 'application/json',
               'Authorization' => "Bearer #{jwt}",
               'X-Cocina-Models-Version' => '0.33.1'
             }
        expect(response).to have_http_status(:bad_request)
        body = JSON.parse(response.body)
        expect(body['errors'][0]['title']).to eq 'Cocina-models version mismatch'
      end
    end

    context 'when the accession flag is set to true' do
      it 'kicks off accession workflow' do
        post '/v1/resources?accession=true',
             params: request,
             headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{jwt}" }
        expect(IngestJob).to have_received(:perform_later).with(model_params: expected_model_params,
                                                                background_job_result: instance_of(BackgroundJobResult),
                                                                signed_ids: [signed_id],
                                                                start_workflow: true,
                                                                assign_doi: false)
      end
    end

    context 'when the accession flag is set to false' do
      it 'does not kick off accession workflow' do
        post '/v1/resources?accession=false',
             params: request,
             headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{jwt}" }
        expect(IngestJob).to have_received(:perform_later).with(model_params: expected_model_params,
                                                                background_job_result: instance_of(BackgroundJobResult),
                                                                signed_ids: [signed_id],
                                                                start_workflow: false,
                                                                assign_doi: false)
      end
    end

    context 'when the assign_doi flag is set to true' do
      it 'kicks off accession workflow' do
        post '/v1/resources?assign_doi=true',
             params: request,
             headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{jwt}" }
        expect(IngestJob).to have_received(:perform_later).with(model_params: expected_model_params,
                                                                background_job_result: instance_of(BackgroundJobResult),
                                                                signed_ids: [signed_id],
                                                                start_workflow: false,
                                                                assign_doi: true)
      end
    end

    context 'when blob not found for file' do
      let(:signed_id) { 'abc123' }

      it 'returns 500' do
        post '/v1/resources',
             params: request,
             headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{jwt}" }
        expect(response).to have_http_status(:server_error)
        body = JSON.parse(response.body)
        expect(body['errors'][0]['title']).to eq 'Error matching uploading files to file parameters.'
      end
    end

    context 'when md5 mismatch' do
      let(:checksum) { 'g5nXiniiM+u/gexbNkOA/A==' }

      it 'returns 500' do
        post '/v1/resources',
             params: request,
             headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{jwt}" }
        expect(response).to have_http_status(:server_error)
        body = JSON.parse(response.body)
        expect(body['errors'][0]['title']).to eq 'Error matching uploading files to file parameters.'
      end
    end
  end
end
