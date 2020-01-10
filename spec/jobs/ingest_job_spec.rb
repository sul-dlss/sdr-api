# frozen_string_literal: true

require 'rails_helper'

RSpec.describe IngestJob, type: :job do
  subject(:run) { described_class.perform_now(druid: druid, background_job_result: result) }

  let(:result) { create(:background_job_result) }
  let(:druid) { 'druid:bc123de5678' }
  let(:client) { instance_double(Dor::Workflow::Client, create_workflow_by_name: true) }

  before do
    allow(Dor::Workflow::Client).to receive(:new).and_return(client)
  end

  it 'creates a workflow' do
    run
    expect(client).to have_received(:create_workflow_by_name).with(druid, 'accessionWF')
    expect(result).to be_complete
  end
end
