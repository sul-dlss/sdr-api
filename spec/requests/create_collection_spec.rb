# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Create a collection' do
  before do
    allow(IngestJob).to receive(:perform_later)
  end

  let(:request) { build(:request_collection).to_json }

  context 'when user has full-access' do
    it 'registers the resource and kicks off IngestJob' do
      post '/v1/resources',
           params: request,
           headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{jwt}" }
      expect(response).to be_created
      expect(response.location).to be_present
      expect(response.parsed_body['jobId']).to be_present
      expect(IngestJob).to have_received(:perform_later).with(model_params: JSON.parse(request),
                                                              background_job_result: instance_of(BackgroundJobResult),
                                                              signed_ids: {},
                                                              globus_ids: {},
                                                              start_workflow: false,
                                                              assign_doi: false,
                                                              priority: 'default',
                                                              user_versions: 'none')
    end
  end

  context 'when user is limited access' do
    let(:limited_user) { create(:user, collections: ['druid:fg123hj4567'], full_access: false) }

    it 'is unauthorized' do
      post '/v1/resources',
           params: request,
           headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{jwt(limited_user)}" }
      expect(response).to be_unauthorized
      expect(IngestJob).not_to have_received(:perform_later)
    end
  end

  context 'when user is inactive' do
    let(:inactive_user) { create(:user, active: false) }

    it 'is unauthorized' do
      post '/v1/resources',
           params: request,
           headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{jwt(inactive_user)}" }
      expect(response).to be_unauthorized
      expect(IngestJob).not_to have_received(:perform_later)
    end
  end
end
