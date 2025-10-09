# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Create a DRO' do
  before do
    allow(IngestJob).to receive(:perform_later)
  end

  let(:dro) { build(:request_dro).new(structural:) }
  let(:request) { dro.to_json }
  let(:structural) do
    {
      isMemberOf: ['druid:fg123hj4567'],
      contains: [
        {
          type: Cocina::Models::FileSetType.file,
          label: 'Page 1',
          structural: {
            contains: [
              {
                externalIdentifier: signed_id,
                type: Cocina::Models::ObjectType.file,
                filename: 'file2.txt',
                label: 'file2.txt',
                hasMessageDigests: [
                  { type: 'md5', digest: '7f99d78a78a233ebbf81ec5b364380fc' },
                  { type: 'sha1', digest: 'c65f99f8c5376adadddc46d5cbcf5762f9e55eb7' }
                ],
                administrative: {
                  publish: false,
                  sdrPreserve: true,
                  shelve: false
                },
                access: {
                  view: 'dark',
                  download: 'none'
                },
                version: 1
              }
            ]
          },
          version: 1
        }
      ]
    }
  end
  let(:checksum) { 'f5nXiniiM+u/gexbNkOA/A==' }
  let(:blob) { create(:singleton_blob_with_file) }
  let(:signed_id) do
    ActiveStorage.verifier.generate(blob.id, purpose: :blob_id)
  end
  let(:expected_content_type) { 'application/text' }
  let(:expected_model_params) do
    model_params = dro.to_h
    file_params = model_params.dig(:structural, :contains, 0, :structural, :contains, 0)
    file_params.delete(:externalIdentifier)
    file_params[:hasMimeType] = expected_content_type
    file_params[:size] = 10
    model_params.with_indifferent_access
  end

  context 'when priority or user versions is not provided' do
    it 'registers the resource and kicks off IngestJob' do
      post '/v1/resources',
           params: request,
           headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{jwt}" }
      expect(response).to be_created
      expect(response.location).to be_present
      expect(response.parsed_body['jobId']).to be_present
      expect(IngestJob).to have_received(:perform_later).with(model_params: expected_model_params,
                                                              background_job_result: instance_of(BackgroundJobResult),
                                                              signed_ids: { 'file2.txt' => signed_id },
                                                              globus_ids: {},
                                                              accession: false,
                                                              assign_doi: false,
                                                              priority: 'default',
                                                              user_versions: 'none')
    end
  end

  context 'when user versions is provided' do
    it 'registers the resource and kicks off IngestJob' do
      post '/v1/resources?user_versions=new',
           params: request,
           headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{jwt}" }
      expect(response).to be_created
      expect(response.location).to be_present
      expect(response.parsed_body['jobId']).to be_present
      expect(IngestJob).to have_received(:perform_later).with(model_params: expected_model_params,
                                                              background_job_result: instance_of(BackgroundJobResult),
                                                              signed_ids: { 'file2.txt' => signed_id },
                                                              globus_ids: {},
                                                              accession: false,
                                                              assign_doi: false,
                                                              priority: 'default',
                                                              user_versions: 'new')
    end
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
      # response.parsed_body gives a string due to "Content-Type"=>"application/vnd.api+json; charset=utf-8"
      expect(JSON.parse(response.body)['errors'][0]['title']).to eq 'Cocina-models version mismatch' # rubocop:disable Rails/ResponseParsedBody
    end
  end

  context 'when the priority flag is set to low' do
    it 'kicks off accession workflow' do
      post '/v1/resources?accession=true&priority=low',
           params: request,
           headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{jwt}" }
      expect(IngestJob).to have_received(:perform_later).with(model_params: expected_model_params,
                                                              background_job_result: instance_of(BackgroundJobResult),
                                                              signed_ids: { 'file2.txt' => signed_id },
                                                              globus_ids: {},
                                                              accession: true,
                                                              assign_doi: false,
                                                              priority: 'low',
                                                              user_versions: 'none')
    end
  end

  context 'when the accession flag is set to true' do
    it 'kicks off accession workflow' do
      post '/v1/resources?accession=true',
           params: request,
           headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{jwt}" }
      expect(IngestJob).to have_received(:perform_later).with(model_params: expected_model_params,
                                                              background_job_result: instance_of(BackgroundJobResult),
                                                              signed_ids: { 'file2.txt' => signed_id },
                                                              globus_ids: {},
                                                              accession: true,
                                                              assign_doi: false,
                                                              priority: 'default',
                                                              user_versions: 'none')
    end
  end

  context 'when the accession flag is set to false' do
    it 'does not kick off accession workflow' do
      post '/v1/resources?accession=false',
           params: request,
           headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{jwt}" }
      expect(IngestJob).to have_received(:perform_later).with(model_params: expected_model_params,
                                                              background_job_result: instance_of(BackgroundJobResult),
                                                              signed_ids: { 'file2.txt' => signed_id },
                                                              globus_ids: {},
                                                              accession: false,
                                                              assign_doi: false,
                                                              priority: 'default',
                                                              user_versions: 'none')
    end
  end

  context 'when the assign_doi flag is set to true' do
    it 'kicks off accession workflow' do
      post '/v1/resources?assign_doi=true',
           params: request,
           headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{jwt}" }
      expect(IngestJob).to have_received(:perform_later).with(model_params: expected_model_params,
                                                              background_job_result: instance_of(BackgroundJobResult),
                                                              signed_ids: { 'file2.txt' => signed_id },
                                                              globus_ids: {},
                                                              accession: false,
                                                              assign_doi: true,
                                                              priority: 'default',
                                                              user_versions: 'none')
    end
  end

  context 'when blob not found for file' do
    let(:signed_id) { ActiveStorage.verifier.generate('thisisinvalid', purpose: :blob_id) }

    it 'returns 500' do
      post '/v1/resources',
           params: request,
           headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{jwt}" }
      expect(response).to have_http_status(:server_error)
      # response.parsed_body gives a string due to "Content-Type"=>"application/vnd.api+json; charset=utf-8"
      expect(JSON.parse(response.body)['errors'][0]['title']).to eq 'Error matching uploading files to file parameters.' # rubocop:disable Rails/ResponseParsedBody
    end
  end

  context 'when the signed_id indicates a globus file' do
    let(:signed_id) { 'globus://abc123/file2.txt' } # This is actually a globus ID but signed_id is used in the request
    let(:globus_ids) { { 'file2.txt' => signed_id } }
    let(:expected_model_params) do
      model_params = dro.to_h
      file_params = model_params.dig(:structural, :contains, 0, :structural, :contains, 0)
      file_params[:size] = 5
      file_params[:hasMimeType] = 'application/octet-stream'
      model_params.with_indifferent_access
    end
    let(:sha1) { 'c65f99f8c5376adadddc46d5cbcf5762f9e55eb7' }
    let(:md5) { 'eb61eead90e3b899c6bcbe27ac581660' }
    let(:file_path) { 'tmp/globus/abc123/file2.txt' }

    before do
      FileUtils.mkdir_p('tmp/globus/abc123')
      FileUtils.cp ActiveStorage::Blob.service.path_for(blob.key), file_path
    end

    it 'kicks off accession workflow' do
      post '/v1/resources',
           params: request,
           headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{jwt}" }
      expect(response).to have_http_status(:created)
      expect(IngestJob).to have_received(:perform_later).with(model_params: expected_model_params,
                                                              background_job_result: instance_of(BackgroundJobResult),
                                                              signed_ids: {},
                                                              globus_ids:,
                                                              accession: false,
                                                              assign_doi: false,
                                                              priority: 'default',
                                                              user_versions: 'none')
    end
  end

  context 'when md5 mismatch' do
    let(:blob) do
      create(:singleton_blob_with_file, checksum:)
    end
    let(:checksum) { 'g5nXiniiM+u/gexbNkOA/A==' }

    it 'returns 500' do
      post '/v1/resources',
           params: request,
           headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{jwt}" }
      expect(response).to have_http_status(:server_error)
      # response.parsed_body gives a string due to "Content-Type"=>"application/vnd.api+json; charset=utf-8"
      expect(JSON.parse(response.body)['errors'][0]['title']).to eq 'Error matching uploading files to file parameters.' # rubocop:disable Rails/ResponseParsedBody
    end
  end

  context 'when the file is application/x-stanford-json' do
    let(:blob) do
      create(:singleton_blob_with_file, content_type: 'application/x-stanford-json')
    end
    let(:expected_content_type) { 'application/json' }

    it 'switches the content type to application/json' do
      post '/v1/resources',
           params: request,
           headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{jwt}" }
      expect(response).to be_created
      expect(response.location).to be_present
      expect(response.parsed_body['jobId']).to be_present
      expect(IngestJob).to have_received(:perform_later).with(model_params: expected_model_params,
                                                              background_job_result: instance_of(BackgroundJobResult),
                                                              signed_ids: { 'file2.txt' => signed_id },
                                                              globus_ids: {},
                                                              accession: false,
                                                              assign_doi: false,
                                                              priority: 'default',
                                                              user_versions: 'none')
    end
  end

  context 'when the file supplies a nil content_type' do
    let(:blob) do
      create(:singleton_blob_with_file, content_type: nil)
    end
    let(:expected_content_type) { 'application/octet-stream' }

    it 'switches the content type to application/octet-stream' do
      post '/v1/resources',
           params: request,
           headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{jwt}" }
      expect(response).to be_created
      expect(response.location).to be_present
      expect(response.parsed_body['jobId']).to be_present
      expect(IngestJob).to have_received(:perform_later).with(model_params: expected_model_params,
                                                              background_job_result: instance_of(BackgroundJobResult),
                                                              signed_ids: { 'file2.txt' => signed_id },
                                                              globus_ids: {},
                                                              accession: false,
                                                              assign_doi: false,
                                                              priority: 'default',
                                                              user_versions: 'none')
    end
  end

  context 'when limited user is authorized for the collection' do
    let(:limited_user) { create(:user, collections: ['druid:fg123hj4567'], full_access: false) }

    it 'registers the resource and kicks off IngestJob' do
      post '/v1/resources',
           params: request,
           headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{jwt(limited_user)}" }
      expect(response).to be_created
      expect(IngestJob).to have_received(:perform_later)
    end
  end

  context 'when limited user is not authorized for the collection' do
    let(:limited_user) { create(:user, collections: ['druid:xg123hj4567'], full_access: false) }

    it 'return unauthorized' do
      post '/v1/resources',
           params: request,
           headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{jwt(limited_user)}" }
      expect(response).to be_unauthorized
      expect(IngestJob).not_to have_received(:perform_later)
    end
  end

  context 'when user is inactive' do
    let(:inactive_user) { create(:user, active: false) }

    it 'return unauthorized' do
      post '/v1/resources',
           params: request,
           headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{jwt(inactive_user)}" }
      expect(response).to be_unauthorized
      expect(IngestJob).not_to have_received(:perform_later)
    end
  end
end
