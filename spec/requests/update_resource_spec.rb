# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Update a resource' do
  let(:structural) do
    {
      'isMemberOf' => ['druid:fg123hj4567'],
      'contains' => [
        {
          'type' => Cocina::Models::FileSetType.file,
          'externalIdentifier' => '9999',
          'label' => 'Page 1',
          'structural' => {
            'contains' => [
              {
                'type' => Cocina::Models::ObjectType.file,
                'filename' => 'file2.txt',
                'label' => 'file2.txt',
                'hasMessageDigests' => [
                  { 'type' => 'md5', 'digest' => '7f99d78a78a233ebbf81ec5b364380fc' },
                  { 'type' => 'sha1', 'digest' => 'c65f99f8c5376adadddc46d5cbcf5762f9e55eb7' }
                ],
                'externalIdentifier' => file_id,
                'administrative' => {
                  'publish' => false,
                  'sdrPreserve' => true,
                  'shelve' => false
                },
                'access' => {
                  'view' => 'dark',
                  'download' => 'none'
                },
                'version' => 1
              }
            ]
          },
          'version' => 1
        }
      ]
    }
  end
  let(:dro) { build(:dro, id: 'druid:bc999dg9999').new(structural: structural) }
  let(:request) { dro.to_json }
  let(:checksum) { 'f5nXiniiM+u/gexbNkOA/A==' }
  let(:blob) do
    ActiveStorage::Blob.create!(key: 'tozuehlw6e8du20vn1xfzmiifyok',
                                filename: 'file2.txt', byte_size: 10, checksum: checksum)
  end
  let(:file_id) do
    ActiveStorage.verifier.generate(blob.id, purpose: :blob_id)
  end
  let(:expected_model_params_without_file_ids) do
    # NOTE: These params are expected when a request expects sdr-api to manage files on its behalf
    expected_model_params_with_file_ids.dup.tap do |model_params|
      file_params = model_params[:structural][:contains][0][:structural][:contains][0]
      file_params.delete(:externalIdentifier)
      file_params[:hasMimeType] = 'application/octet-stream'
      file_params[:size] = 10
      file_params[:externalIdentifier] = 'https://cocina.sul.stanford.edu/file/bc999dg9999-9999/ffef5496-7b89-4df6-b8c0-de37805a43ec'
    end
  end
  let(:expected_model_params_with_file_ids) do
    # NOTE: These params are expected when a request expects sdr-api NOT to manage files on its behalf
    dro.to_h.with_indifferent_access
  end
  let(:version_description) { 'Updated metadata' }

  before do
    allow(UpdateJob).to receive(:perform_later)
    allow(SecureRandom).to receive(:uuid).and_return('ffef5496-7b89-4df6-b8c0-de37805a43ec')
  end

  it 'registers the resource and kicks off UpdateJob' do
    put "/v1/resources/druid:bc999dg9999?versionDescription=#{version_description}",
        params: request,
        headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{jwt}" }

    expect(response).to be_accepted
    expect(response.location).to be_present
    expect(JSON.parse(response.body)['jobId']).to be_present
    expect(UpdateJob).to have_received(:perform_later).with(model_params: expected_model_params_without_file_ids,
                                                            background_job_result: instance_of(BackgroundJobResult),
                                                            signed_ids: { 'file2.txt' => file_id },
                                                            version_description: version_description)
  end

  context 'when wrong version of cocina models is supplied' do
    it 'returns 400' do
      put '/v1/resources/druid:bc123df4567',
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

  context 'when blob not found for file' do
    let(:file_id) { 'abc123' }

    before do
      allow(ActiveStorage.verifier).to receive(:valid_message?).and_return(true)
    end

    it 'returns 500' do
      put '/v1/resources/druid:bc123df4567',
          params: request,
          headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{jwt}" }
      expect(response).to have_http_status(:server_error)
      body = JSON.parse(response.body)
      expect(body['errors'][0]['title']).to eq 'Error matching uploading files to file parameters.'
    end
  end

  context 'when file ID is an HTTP URI' do
    let(:file_id) { 'http://cocina.sul.stanford.edu/file/foobar' }

    it 'registers the resource and kicks off UpdateJob' do
      put '/v1/resources/druid:bc123df4567',
          params: request,
          headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{jwt}" }
      expect(response).to be_accepted
      expect(response.location).to be_present
      expect(JSON.parse(response.body)['jobId']).to be_present
      expect(UpdateJob).to have_received(:perform_later).with(model_params: expected_model_params_with_file_ids,
                                                              background_job_result: instance_of(BackgroundJobResult),
                                                              signed_ids: {}, version_description: nil)
    end
  end

  context 'when file ID is an HTTPS URI' do
    let(:file_id) { 'https://cocina.sul.stanford.edu/file/foobar' }

    it 'registers the resource and kicks off UpdateJob' do
      put '/v1/resources/druid:bc123df4567',
          params: request,
          headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{jwt}" }
      expect(response).to be_accepted
      expect(response.location).to be_present
      expect(JSON.parse(response.body)['jobId']).to be_present
      expect(UpdateJob).to have_received(:perform_later).with(model_params: expected_model_params_with_file_ids,
                                                              background_job_result: instance_of(BackgroundJobResult),
                                                              signed_ids: {}, version_description: nil)
    end
  end

  context 'when md5 mismatch' do
    let(:checksum) { 'g5nXiniiM+u/gexbNkOA/A==' }

    it 'returns 500' do
      put '/v1/resources/druid:bc123df4567',
          params: request,
          headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{jwt}" }
      expect(response).to have_http_status(:server_error)
      body = JSON.parse(response.body)
      expect(body['errors'][0]['title']).to eq 'Error matching uploading files to file parameters.'
    end
  end

  context 'when limited user is authorized for the collection' do
    let(:limited_user) { create(:user, collections: ['druid:fg123hj4567'], full_access: false) }

    it 'registers the resource and kicks off UpdateJob' do
      put "/v1/resources/druid:bc999dg9999?versionDescription=#{version_description}",
          params: request,
          headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{jwt(limited_user)}" }

      expect(response).to be_accepted
      expect(UpdateJob).to have_received(:perform_later)
    end
  end

  context 'when limited user is not authorized for the collection' do
    let(:limited_user) { create(:user, collections: ['druid:xg123hj4567'], full_access: false) }

    it 'returns unauthorized' do
      put "/v1/resources/druid:bc999dg9999?versionDescription=#{version_description}",
          params: request,
          headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{jwt(limited_user)}" }

      expect(response).to be_unauthorized
      expect(UpdateJob).not_to have_received(:perform_later)
    end
  end

  context 'when inactive user' do
    let(:inactive_user) { create(:user, active: false) }

    it 'returns unauthorized' do
      put "/v1/resources/druid:bc999dg9999?versionDescription=#{version_description}",
          params: request,
          headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{jwt(inactive_user)}" }

      expect(response).to be_unauthorized
      expect(UpdateJob).not_to have_received(:perform_later)
    end
  end
end
