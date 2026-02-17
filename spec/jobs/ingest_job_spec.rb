# frozen_string_literal: true

require 'rails_helper'

RSpec.describe IngestJob do
  let(:try_count) { 0 }
  let(:result) { create(:background_job_result, try_count:) }
  let(:actual_result) { BackgroundJobResult.find(result.id) }
  let(:druid) { 'druid:bc123dh5678' }
  let(:object_client) { instance_double(Dor::Services::Client::Object, version: version_client, update: true) }
  let(:version_client) do
    instance_double(Dor::Services::Client::ObjectVersion, close: true)
  end
  let(:blob) { create(:singleton_blob_with_file) }
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
  let(:user_versions) { 'none' }
  let(:priority) { 'default' }

  before do
    FileUtils.rm_rf('tmp/assembly/bc')
    FileUtils.rm_rf('tmp/globus')
    FileUtils.mkdir_p('tmp/globus/some/file/path')
    FileUtils.cp blob.service.path_for(blob.key), 'tmp/globus/some/file/path/file2.txt'
    allow(Dor::Services::Client).to receive_messages(objects: objects_client, object: object_client)
    allow(ActiveStorage::PurgeJob).to receive(:perform_later)
    allow(Workflow).to receive(:create_unless_exists)
  end

  context 'when API calls are successful' do
    let(:objects_client) { instance_double(Dor::Services::Client::Objects, register: response_dro) }

    before do
      described_class.perform_now(model_params: model,
                                  background_job_result: result,
                                  signed_ids:,
                                  priority:,
                                  user_versions:)
    end

    context 'when priority is default' do
      it 'ingests an object' do
        expect(File.read("#{assembly_dir}/content/file2.txt")).to eq 'HELLO'
        expect(Workflow).to have_received(:create_unless_exists).with(druid, 'registrationWF', version: 1, priority:)
        expect(version_client).to have_received(:close).with(user_versions: 'none')
        expect(actual_result).to be_complete
        expect(actual_result.output).to match({ druid: })
        expect(ActiveStorage::PurgeJob).to have_received(:perform_later).with(blob)
      end
    end

    context 'when user_versions is provided' do
      let(:user_versions) { 'new' }

      it 'ingests an object' do
        expect(version_client).to have_received(:close).with(user_versions: 'new')
        expect(actual_result).to be_complete
      end
    end
  end

  context 'when files are on globus' do
    let(:objects_client) { instance_double(Dor::Services::Client::Objects, register: response_dro) }
    let(:priority) { 'default' }
    let(:globus_ids) do
      { 'file2.txt' => 'globus://some/file/path/file2.txt' }
    end

    before do
      described_class.perform_now(model_params: model,
                                  background_job_result: result,
                                  globus_ids:,
                                  priority:)
    end

    it 'ingests an object' do
      expect(File.read("#{assembly_dir}/content/file2.txt")).to eq 'HELLO'
      expect(Workflow).to have_received(:create_unless_exists).with(druid, 'registrationWF', version: 1, priority:)
      expect(version_client).to have_received(:close)
      expect(actual_result).to be_complete
      expect(actual_result.output).to match({ druid: })
    end
  end

  context 'when assigning DOI' do
    let(:objects_client) { instance_double(Dor::Services::Client::Objects, register: response_dro) }

    it 'ingests an object' do
      described_class.perform_now(model_params: model, background_job_result: result, signed_ids:,
                                  assign_doi: true)
      expect(objects_client).to have_received(:register).with(params: Cocina::Models::RequestDRO.new(model),
                                                              assign_doi: true)
    end
  end

  context 'when registering only' do
    let(:objects_client) { instance_double(Dor::Services::Client::Objects, register: response_dro) }

    it 'ingests an object without closing' do
      described_class.perform_now(model_params: model, background_job_result: result, signed_ids:,
                                  accession: false)
      expect(objects_client).to have_received(:register).with(params: Cocina::Models::RequestDRO.new(model),
                                                              assign_doi: false)
      expect(version_client).not_to have_received(:close)
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
      described_class.perform_now(model_params: model,
                                  background_job_result: result,
                                  signed_ids:)
      expect(Workflow).not_to have_received(:create_unless_exists)
      expect(actual_result).to be_complete
      expect(actual_result.output)
        .to match({ errors: [{ title: 'Object with source_id already exists.',
                               message: "Obj (#{druid}) already exists ()" }] })
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
      described_class.perform_now(model_params: model,
                                  background_job_result: result,
                                  signed_ids:)
      expect(File.read("#{assembly_dir}/content/file2.txt")).to eq 'HELLO'
      expect(Workflow).to have_received(:create_unless_exists).with(druid, 'registrationWF', version: 1, priority:)
      expect(version_client).to have_received(:close)
      expect(actual_result).to be_complete
      expect(actual_result.output).to match({ druid: })
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
                                                                { 'title' => 'Record not in catalog blah blah' }
                                                              ]))
    end

    it 'reports error and will not retry' do
      described_class.perform_now(model_params: model,
                                  background_job_result: result,
                                  signed_ids:)
      expect(Workflow).not_to have_received(:create_unless_exists)
      expect(actual_result).to be_complete
      expect(actual_result.output)
        .to match({ errors: [{ title: 'HTTP 400 (Bad Request) from dor-services-app',
                               message: 'Record not in catalog blah blah ()' }] })
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
                                      signed_ids:)
        end
          .to raise_error(StandardError)
        expect(actual_result).to be_pending
      end
    end

    context 'without retries' do
      let(:try_count) { 8 }

      it 'quits' do
        described_class.perform_now(model_params: model,
                                    background_job_result: result,
                                    signed_ids:)
        expect(actual_result).to be_complete
        expect(actual_result.output[:errors]).to be_present
      end
    end
  end

  context 'when closing the version raises an error and does not succeed on retry' do
    let(:try_count) { 8 }
    let(:objects_client) { instance_double(Dor::Services::Client::Objects, register: response_dro) }
    let(:version_client) do
      instance_double(Dor::Services::Client::ObjectVersion)
    end

    before do
      allow(Honeybadger).to receive(:notify)
      allow(version_client)
        .to receive(:close)
        .and_raise(Dor::Services::Client::BadRequestError.new(response: '',
                                                              errors: [
                                                                { title: 'Unable to close version' }
                                                              ]))
      described_class.perform_now(model_params: model,
                                  background_job_result: result,
                                  signed_ids:)
    end

    it 'reports an error' do
      expect(actual_result).to be_complete
      expect(actual_result.output)
        .to match({ druid: 'druid:bc123dh5678',
                    errors: [{ title: 'All retries failed',
                               message: ' ()' }] }.with_indifferent_access)
      expect(ActiveStorage::PurgeJob).to have_received(:perform_later).with(blob)
      expect(Honeybadger).to have_received(:notify).with('All retries failed',
                                                         context: { external_identifier: 'druid:bc123dh5678' })
    end
  end
end
