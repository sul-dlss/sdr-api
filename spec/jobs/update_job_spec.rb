# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UpdateJob do
  let(:try_count) { 0 }
  let(:result) { create(:background_job_result, try_count:) }
  let(:actual_result) { BackgroundJobResult.find(result.id) }
  let(:druid) { 'druid:bc123dg5678' }
  let(:workflow_client) { instance_double(Dor::Workflow::Client, create_workflow_by_name: true) }
  let(:blob) do
    ActiveStorage::Blob.create!(key: 'tozuehlw6e8du20vn1xfzmiifyok',
                                filename: 'file2.txt', byte_size: 10, checksum: 'f5nXiniiM+u/gexbNkOA/A==')
  end
  let(:signed_ids) do
    { 'file2.txt' => ActiveStorage.verifier.generate(blob.id, purpose: :blob_id) }
  end

  let(:update_version) { 2 }
  let(:model) do
    build(:dro, id: druid, version: update_version).new(structural: { contains: filesets }).to_h
  end

  let(:file) do
    {
      type: Cocina::Models::ObjectType.file,
      filename: 'file2.txt',
      externalIdentifier: "#{druid}/file2.txt",
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
        externalIdentifier: 'bc123df4567_1',
        label: 'Page 1',
        structural: { contains: [file] },
        version: 1
      }
    ]
  end

  let(:existing_version) { 1 }
  let(:response_dro) do
    build(:dro, id: druid, version: existing_version)
  end

  let(:assembly_dir) { 'tmp/assembly/bc/123/dg/5678/bc123dg5678' }
  let(:version_client) { instance_double(Dor::Services::Client::ObjectVersion, open: true, close: true) }

  let(:accession_client) { instance_double(Dor::Services::Client::Accession, start: true) }
  let(:object_client) do
    instance_double(Dor::Services::Client::Object,
                    find: response_dro, version: version_client, update: true, accession: accession_client)
  end

  before do
    FileUtils.rm_rf('tmp/assembly/bc')
    FileUtils.mkdir_p('tmp/storage/to/zu')
    File.write('tmp/storage/to/zu/tozuehlw6e8du20vn1xfzmiifyok', 'HELLO')
    allow(Dor::Services::Client).to receive(:object).with(druid).and_return(object_client)
    allow(ActiveStorage::PurgeJob).to receive(:perform_later)
    allow(Honeybadger).to receive(:notify)
  end

  context 'when updating to a new version' do
    it 'updates the metadata, purges the staged files, and marks the job complete for the druid' do
      described_class.perform_now(model_params: model,
                                  background_job_result: result,
                                  signed_ids:)
      cocina_object = Cocina::Models.build(model.with_indifferent_access)
      expect(object_client).to have_received(:update).with(params: cocina_object, skip_lock: true)
      expect(actual_result).to be_complete
      expect(actual_result.output).to match({ druid: })
      expect(ActiveStorage::PurgeJob).to have_received(:perform_later).with(blob)
    end

    it 'accessions an object by default without explicitly opening/closing a version' do
      described_class.perform_now(model_params: model,
                                  background_job_result: result,
                                  signed_ids:,
                                  version_description: 'Updated metadata')
      expect(File.read("#{assembly_dir}/content/file2.txt")).to eq 'HELLO'
      expect(version_client).not_to have_received(:open)
      expect(version_client).not_to have_received(:close)
      expect(accession_client).to have_received(:start)
        .with(description: 'Updated metadata', significance: 'major', workflow: 'accessionWF').once
    end

    it 'opens and closes the version without kicking off accessioning if start_workflow is false' do
      described_class.perform_now(model_params: model,
                                  background_job_result: result,
                                  signed_ids:,
                                  start_workflow: false)
      expect(version_client).to have_received(:open).once
      expect(version_client).to have_received(:close)
        .with(description: 'Update via sdr-api', significance: 'major', start_accession: false).once
      expect(accession_client).not_to have_received(:start)
    end
  end

  context 'when Dor::Services::Client::BadRequestError error' do
    let(:object_client) do
      instance_double(Dor::Services::Client::Object, find: response_dro, version: version_client)
    end

    before do
      allow(object_client)
        .to receive(:update)
        .and_raise(Dor::Services::Client::BadRequestError.new(response: '',
                                                              errors: [
                                                                { 'title' => 'cocina validation error blah blah' }
                                                              ]))
    end

    it 'reports error and will not retry' do
      described_class.perform_now(model_params: model,
                                  background_job_result: result,
                                  signed_ids:)
      expect(actual_result).to be_complete
      expect(actual_result.output)
        .to match({ errors: [title: 'HTTP 400 (Bad Request) from dor-services-app',
                             message: 'cocina validation error blah blah ()'] })
      expect(ActiveStorage::PurgeJob).not_to have_received(:perform_later).with(blob)
    end
  end

  context 'when Dor::Services::Client::ConflictResponse error' do
    let(:object_client) do
      instance_double(Dor::Services::Client::Object, find: response_dro, version: version_client)
    end

    before do
      allow(object_client)
        .to receive(:update)
        .and_raise(Dor::Services::Client::ConflictResponse.new(response: '',
                                                               errors: [
                                                                 { 'title' => 'cocina roundtrip validation error ...' }
                                                               ]))
    end

    it 'reports error and will not retry' do
      described_class.perform_now(model_params: model,
                                  background_job_result: result,
                                  signed_ids:)
      expect(actual_result).to be_complete
      expect(actual_result.output)
        .to match({ errors: [title: 'HTTP 409 (Conflict) from dor-services-app',
                             message: 'cocina roundtrip validation error ... ()'] })
      expect(ActiveStorage::PurgeJob).not_to have_received(:perform_later).with(blob)
    end
  end

  context 'when StandardError raised' do
    let(:object_client) do
      instance_double(Dor::Services::Client::Object, find: response_dro, version: version_client)
    end

    before do
      allow(object_client).to receive(:update).and_raise(StandardError, 'Something went wrong')
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

  context 'when updating the current version' do
    let(:existing_version) { 2 }

    it 'updates the metadata, purges the staged files, and marks the job complete for the druid' do
      described_class.perform_now(model_params: model,
                                  background_job_result: result,
                                  signed_ids:)
      cocina_object = Cocina::Models.build(model.with_indifferent_access)
      expect(object_client).to have_received(:update).with(params: cocina_object, skip_lock: true)
      expect(actual_result).to be_complete
      expect(actual_result.output).to match({ druid: })
      expect(ActiveStorage::PurgeJob).to have_received(:perform_later).with(blob)
    end

    it 'accessions an object by default without explicitly opening/closing a version' do
      described_class.perform_now(model_params: model,
                                  background_job_result: result,
                                  signed_ids:)
      expect(File.read("#{assembly_dir}/content/file2.txt")).to eq 'HELLO'
      expect(version_client).not_to have_received(:open)
      expect(version_client).not_to have_received(:close)
      expect(accession_client).to have_received(:start)
        .with(description: 'Update via sdr-api', significance: 'major', workflow: 'accessionWF').once
    end

    it 'does not kick off accessioning if start_workflow is false' do
      described_class.perform_now(model_params: model, background_job_result: result,
                                  signed_ids:, start_workflow: false)
      expect(accession_client).not_to have_received(:start)
    end

    it 'does not open/close the version' do
      described_class.perform_now(model_params: model, background_job_result: result,
                                  signed_ids:, start_workflow: false)
      expect(version_client).not_to have_received(:open)
      expect(version_client).not_to have_received(:close)
    end
  end

  context 'when updating neither the current version nor the next version' do
    let(:update_version) { 5 }
    let(:existing_version) { 3 }

    it 'quits with an error' do
      described_class.perform_now(model_params: model,
                                  background_job_result: result,
                                  signed_ids:)

      err_title = 'Version conflict'
      err_detail = "The repository is on version '3' and " \
                   "you tried to create/update version '5'. Version is limited to 3 or 4."

      expect(actual_result).to be_complete
      expect(actual_result.output[:errors]).to eq [{ 'title' => err_title, 'detail' => err_detail }]
      expect(Honeybadger).to have_received(:notify).with("#{err_title}: #{err_detail}", {
                                                           current_version: 3,
                                                           external_identifier: 'druid:bc123dg5678',
                                                           provided_version: 5
                                                         })
    end
  end

  context 'when updating Globus deposits that lack digests' do
    before do
      FileUtils.rm_rf('tmp/globus/digest-test')
      FileUtils.mkdir_p('tmp/globus/digest-test')
      FileUtils.cp('spec/fixtures/00001.jp2', 'tmp/globus/digest-test/00001.jp2')
    end

    let(:file) do
      {
        type: Cocina::Models::ObjectType.file,
        filename: '00001.jp2',
        externalIdentifier: "#{druid}/00001.jp2",
        label: '00001.jp2',
        hasMimeType: 'image/jp2',
        administrative: {
          publish: false,
          sdrPreserve: true,
          shelve: false
        },
        access: {
          view: 'dark',
          download: 'none'
        },
        hasMessageDigests: [],
        version: 1
      }
    end

    it 'sha1 and md5 digests are generated' do
      described_class.perform_now(model_params: model,
                                  background_job_result: result,
                                  signed_ids: {},
                                  globus_ids: { '00001.jp2' => 'globus://digest-test/00001.jp2' })
      model_with_digests = model.deep_dup
      model_with_digests[:structural][:contains][0][:structural][:contains][0][:hasMessageDigests] = [
        { type: 'sha1', digest: 'da39a3ee5e6b4b0d3255bfef95601890afd80709' },
        { type: 'md5', digest: 'd41d8cd98f00b204e9800998ecf8427e' }
      ]
      cocina_object = Cocina::Models.build(model_with_digests.with_indifferent_access)
      expect(object_client).to have_received(:update).with(params: cocina_object, skip_lock: true)
      expect(actual_result).to be_complete
      expect(actual_result.output).to match({ druid: })
    end
  end
end
