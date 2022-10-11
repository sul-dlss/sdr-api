# frozen_string_literal: true

require 'rails_helper'

RSpec.describe IngestJob, type: :job do
  let(:try_count) { 0 }
  let(:result) { create(:background_job_result, try_count: try_count) }
  let(:actual_result) { BackgroundJobResult.find(result.id) }
  let(:druid) { 'druid:bc123dh5678' }
  let(:workflow_client) { instance_double(Dor::Workflow::Client, create_workflow_by_name: true, workflow: workflow) }
  let(:workflow) { instance_double(Dor::Workflow::Response::Workflow, empty?: true) }
  let(:blob) do
    ActiveStorage::Blob.create!(key: 'tozuehlw6e8du20vn1xfzmiifyok',
                                filename: 'file2.txt', byte_size: 10, checksum: 'f5nXiniiM+u/gexbNkOA/A==')
  end
  let(:signed_ids) do
    { 'file2.txt' => ActiveStorage.verifier.generate(blob.id, purpose: :blob_id) }
  end

  let(:model) do
    build(:request_dro).new(structural: { contains: filesets }).to_h
  end

  let(:file) do
    {
      type: Cocina::Models::ObjectType.file,
      filename: 'file2.txt',
      label: 'file2.txt',
      hasMimeType: 'text/plain',
      administrative: {
        publish: false,
        sdrPreserve: true,
        shelve: false
      },
      access: {
        view: 'dark',
        download: 'none'
      },
      hasMessageDigests: [
        { type: 'md5', digest: '7f99d78a78a233ebbf81ec5b364380fc' },
        { type: 'sha1', digest: 'c65f99f8c5376adadddc46d5cbcf5762f9e55eb7' }
      ],
      version: 1
    }
  end

  let(:filesets) do
    [
      {
        type: Cocina::Models::FileSetType.file,
        label: 'Page 1',
        structural: { contains: [file] },
        version: 1
      }
    ]
  end

  let(:response_dro) do
    build(:dro, id: druid)
  end

  let(:assembly_dir) { 'tmp/assembly/bc/123/dh/5678/bc123dh5678' }

  before do
    FileUtils.rm_rf('tmp/assembly/bc')
    FileUtils.mkdir_p('tmp/storage/to/zu')
    File.write('tmp/storage/to/zu/tozuehlw6e8du20vn1xfzmiifyok', 'HELLO')
    allow(Dor::Workflow::Client).to receive(:new).and_return(workflow_client)
    allow(Dor::Services::Client).to receive(:objects).and_return(objects_client)
    allow(ActiveStorage::PurgeJob).to receive(:perform_later)
  end

  context 'when API calls are successful' do
    let(:objects_client) { instance_double(Dor::Services::Client::Objects, register: response_dro) }

    before do
      described_class.perform_now(model_params: model,
                                  background_job_result: result,
                                  signed_ids: signed_ids,
                                  priority: priority)
    end

    context 'when priority is default' do
      let(:priority) { 'default' }

      it 'ingests an object' do
        expect(File.read("#{assembly_dir}/content/file2.txt")).to eq 'HELLO'
        expect(workflow_client).to have_received(:workflow).with(pid: druid, workflow_name: 'registrationWF')
        expect(workflow_client).to have_received(:workflow).with(pid: druid, workflow_name: 'accessionWF')
        expect(workflow_client).to have_received(:create_workflow_by_name)
          .with(druid, 'registrationWF', version: 1, lane_id: 'default')
        expect(workflow_client).to have_received(:create_workflow_by_name)
          .with(druid, 'accessionWF', version: 1, lane_id: 'default')
        expect(actual_result).to be_complete
        expect(actual_result.output).to match({ druid: druid })
        expect(ActiveStorage::PurgeJob).to have_received(:perform_later).with(blob)
      end
    end

    context 'when priority is low' do
      let(:priority) { 'low' }

      it 'ingests an object' do
        expect(File.read("#{assembly_dir}/content/file2.txt")).to eq 'HELLO'
        expect(workflow_client).to have_received(:workflow).with(pid: druid, workflow_name: 'registrationWF')
        expect(workflow_client).to have_received(:workflow).with(pid: druid, workflow_name: 'accessionWF')
        expect(workflow_client).to have_received(:create_workflow_by_name)
          .with(druid, 'registrationWF', version: 1, lane_id: 'low')
        expect(workflow_client).to have_received(:create_workflow_by_name)
          .with(druid, 'accessionWF', version: 1, lane_id: 'low')
        expect(actual_result).to be_complete
        expect(actual_result.output).to match({ druid: druid })
        expect(ActiveStorage::PurgeJob).to have_received(:perform_later).with(blob)
      end
    end
  end

  context 'when assigning DOI' do
    let(:objects_client) { instance_double(Dor::Services::Client::Objects, register: response_dro) }

    it 'ingests an object' do
      described_class.perform_now(model_params: model, background_job_result: result, signed_ids: signed_ids,
                                  assign_doi: true)
      expect(objects_client).to have_received(:register).with(params: Cocina::Models::RequestDRO.new(model),
                                                              assign_doi: true)
    end
  end

  context 'when Dor::Services::Client::ConflictResponse on first register attempt' do
    let(:objects_client) { instance_double(Dor::Services::Client::Objects) }

    before do
      allow(objects_client)
        .to receive(:register)
        .and_raise(Dor::Services::Client::ConflictResponse.new(response: '',
                                                               errors: [
                                                                 { 'title' => "Obj (#{druid}) already exists" }
                                                               ]))
    end

    it 'quits' do
      described_class.perform_now(model_params: model, background_job_result: result, signed_ids: signed_ids)
      expect(workflow_client).not_to have_received(:workflow)
        .with(pid: druid, workflow_name: 'registrationWF')
      expect(workflow_client).not_to have_received(:workflow)
        .with(pid: druid, workflow_name: 'accessionWF')
      expect(actual_result).to be_complete
      expect(actual_result.output)
        .to match({ errors: [title: 'Object with source_id already exists.',
                             message: "Obj (#{druid}) already exists ()"] })
      expect(ActiveStorage::PurgeJob).not_to have_received(:perform_later).with(blob)
    end
  end

  context 'when conflict on subsequent register attempts' do
    let(:try_count) { 2 }
    let(:objects_client) { instance_double(Dor::Services::Client::Objects) }

    before do
      allow(objects_client).to receive(:register)
        .and_raise(Dor::Services::Client::ConflictResponse.new(response: '',
                                                               errors: [
                                                                 { 'title' => "Obj (#{druid}) already exists" }
                                                               ]))
    end

    it 'retries' do
      described_class.perform_now(model_params: model, background_job_result: result, signed_ids: signed_ids)
      expect(File.read("#{assembly_dir}/content/file2.txt")).to eq 'HELLO'
      expect(workflow_client).to have_received(:workflow).with(pid: druid, workflow_name: 'registrationWF')
      expect(workflow_client).to have_received(:workflow).with(pid: druid, workflow_name: 'accessionWF')
      expect(workflow_client).to have_received(:create_workflow_by_name)
        .with(druid, 'registrationWF', version: 1, lane_id: 'default')
      expect(workflow_client).to have_received(:create_workflow_by_name)
        .with(druid, 'accessionWF', version: 1, lane_id: 'default')
      expect(actual_result).to be_complete
      expect(actual_result.output).to match({ druid: druid })
      expect(ActiveStorage::PurgeJob).to have_received(:perform_later).with(blob)
    end
  end

  context 'when workflow already exists' do
    let(:objects_client) { instance_double(Dor::Services::Client::Objects, register: response_dro) }

    before do
      allow(workflow).to receive(:empty?).and_return(false)
    end

    it 'ingests an object' do
      described_class.perform_now(model_params: model, background_job_result: result, signed_ids: signed_ids)
      expect(File.read("#{assembly_dir}/content/file2.txt")).to eq 'HELLO'
      expect(workflow_client).to have_received(:workflow).with(pid: druid, workflow_name: 'registrationWF')
      expect(workflow_client).to have_received(:workflow).with(pid: druid, workflow_name: 'accessionWF')
      expect(workflow_client).not_to have_received(:create_workflow_by_name)
        .with(druid, 'registrationWF', version: 1, lane_id: 'low')
      expect(workflow_client).not_to have_received(:create_workflow_by_name)
        .with(druid, 'accessionWF', version: 1, lane_id: 'low')
      expect(actual_result).to be_complete
      expect(actual_result.output).to match({ druid: druid })
      expect(ActiveStorage::PurgeJob).to have_received(:perform_later).with(blob)
    end
  end

  context 'when Dor::Services::Client::BadRequestError error' do
    let(:objects_client) { instance_double(Dor::Services::Client::Objects) }

    before do
      allow(objects_client)
        .to receive(:register)
        .and_raise(Dor::Services::Client::BadRequestError.new(response: '',
                                                              errors: [
                                                                { 'title' => 'Catkey not in Symphony blah blah' }
                                                              ]))
    end

    it 'reports error and will not retry' do
      described_class.perform_now(model_params: model, background_job_result: result, signed_ids: signed_ids)
      expect(workflow_client).not_to have_received(:workflow)
        .with(pid: druid, workflow_name: 'registrationWF')
      expect(workflow_client).not_to have_received(:workflow)
        .with(pid: druid, workflow_name: 'accessionWF')
      expect(actual_result).to be_complete
      expect(actual_result.output)
        .to match({ errors: [title: 'HTTP 400 (Bad Request) from dor-services-app',
                             message: 'Catkey not in Symphony blah blah ()'] })
      expect(ActiveStorage::PurgeJob).not_to have_received(:perform_later).with(blob)
    end
  end

  context 'when error raised' do
    let(:objects_client) { instance_double(Dor::Services::Client::Objects) }

    before do
      allow(objects_client).to receive(:register).and_raise(StandardError, 'Something went wrong')
    end

    context 'with retries' do
      it 'retries' do
        expect do
          described_class.perform_now(model_params: model,
                                      background_job_result: result,
                                      signed_ids: signed_ids)
        end
          .to raise_error(StandardError)
        expect(actual_result).to be_pending
      end
    end

    context 'without retries' do
      let(:try_count) { 8 }

      it 'quits' do
        described_class.perform_now(model_params: model, background_job_result: result, signed_ids: signed_ids)
        expect(actual_result).to be_complete
        expect(actual_result.output[:errors]).to be_present
      end
    end
  end
end
