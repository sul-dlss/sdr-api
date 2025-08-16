# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Workflow do
  let(:object_client) { instance_double(Dor::Services::Client::Object, workflow: workflow_client) }
  let(:workflow_client) { instance_double(Dor::Services::Client::ObjectWorkflow, create: true, find: workflow_response) }
  let(:workflow_response) { instance_double(Dor::Services::Response::Workflow, present?: workflow_present) }
  let(:workflow_present) { true }

  let(:druid) { 'druid:bc123df4567' }

  before do
    allow(Dor::Services::Client).to receive(:object).and_return(object_client)
  end

  describe '#create_unless_exists' do
    context 'when the workflow exists' do
      it 'does not create a new workflow' do
        described_class.create_unless_exists(druid, 'accessionWF')

        expect(Dor::Services::Client).to have_received(:object).with(druid)
        expect(object_client).to have_received(:workflow).with('accessionWF')
        expect(workflow_client).to have_received(:find)
        expect(workflow_client).not_to have_received(:create)
      end
    end

    context 'when the workflow does not exist' do
      let(:workflow_present) { false }

      it 'creates a new workflow' do
        described_class.create_unless_exists(druid, 'accessionWF', version: 2, priority: 'low')

        expect(workflow_client).to have_received(:create).with(version: 2, lane_id: 'low')
      end
    end
  end
end
