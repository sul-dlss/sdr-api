# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UpdateJob do
  let(:try_count) { 0 }
  let(:result) { create(:background_job_result, try_count:) }
  let(:actual_result) { BackgroundJobResult.find(result.id) }
  let(:druid) { 'druid:bc123dg5678' }
  let(:workflow_client) { instance_double(Dor::Workflow::Client, create_workflow_by_name: true) }
  let(:blob) { create(:singleton_blob_with_file) }
  let(:signed_ids) do
    { 'file2.txt' => ActiveStorage.verifier.generate(blob.id, purpose: :blob_id) }
  end
  let(:update_version) { 2 }
  let(:model) do
    build(:dro, id: druid, version: update_version).new(structural: { contains: filesets })
  end
  let(:model_with_metadata) do
    Cocina::Models.with_metadata(model, 'abc123', created: Time.current, modified: Time.current)
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
      version: 2
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
  let(:assembly_dir) { 'tmp/assembly/bc/123/dg/5678/bc123dg5678' }
  let(:version_client) do
    instance_double(Dor::Services::Client::ObjectVersion, open: model_with_metadata, close: true,
                                                          status: existing_version_status)
  end
  let(:existing_version_status) do
    instance_double(Dor::Services::Client::ObjectVersion::VersionStatus, version: existing_version, openable?: true)
  end
  let(:object_client) do
    instance_double(Dor::Services::Client::Object, version: version_client, update: true)
  end

  before do
    FileUtils.rm_rf('tmp/assembly/bc')
    allow(Dor::Services::Client).to receive(:object).with(druid).and_return(object_client)
    allow(ActiveStorage::PurgeJob).to receive(:perform_later)
    allow(Honeybadger).to receive(:notify)
  end

  context 'when updating to a new version' do
    context 'when openable' do
      it 'opens the version, updates the metadata, purges the staged files, and marks the job complete for the druid' do
        described_class.perform_now(model_params: model.to_h,
                                    background_job_result: result,
                                    signed_ids:)
        expect(version_client).to have_received(:open).with(description: 'Update via sdr-api').once
        expect(object_client).to have_received(:update).with(params: model, skip_lock: true)
        expect(version_client).to have_received(:close).with(user_versions: 'none')
        expect(actual_result).to be_complete
        expect(actual_result.output).to match({ druid: })
        expect(ActiveStorage::PurgeJob).to have_received(:perform_later).with(blob)
      end
    end

    context 'when not openable' do
      before do
        allow(existing_version_status).to receive(:openable?).and_return(false)
      end

      it 'reports error and will not retry' do
        described_class.perform_now(model_params: model.to_h,
                                    background_job_result: result,
                                    signed_ids:)
        expect(actual_result).to be_complete
        expect(actual_result.output)
          .to match({ errors: [{ title: 'Version not openable',
                                 detail: 'Attempted to open version 2 but it cannot be opened.' }] })
        expect(version_client).not_to have_received(:open)
      end
    end

    context 'when not accessioning' do
      it 'does not close the version' do
        described_class.perform_now(model_params: model.to_h,
                                    background_job_result: result,
                                    signed_ids:, accession: false)
        expect(version_client).to have_received(:open).with(description: 'Update via sdr-api').once
        expect(object_client).to have_received(:update).with(params: model, skip_lock: true)
        expect(version_client).not_to have_received(:close)
        expect(actual_result).to be_complete
        expect(actual_result.output).to match({ druid: })
        expect(ActiveStorage::PurgeJob).to have_received(:perform_later).with(blob)
      end
    end
  end

  context 'when user_version provided' do
    it 'calls version close with user_version' do
      described_class.perform_now(model_params: model.to_h,
                                  background_job_result: result,
                                  signed_ids:,
                                  user_versions: 'new')
      expect(version_client).to have_received(:close).with(user_versions: 'new')
      expect(actual_result).to be_complete
    end
  end

  context 'when Dor::Services::Client::BadRequestError error' do
    before do
      allow(object_client)
        .to receive(:update)
        .and_raise(Dor::Services::Client::BadRequestError.new(response: '',
                                                              errors: [
                                                                { 'title' => 'cocina validation error blah blah' }
                                                              ]))
    end

    it 'reports error and will not retry' do
      described_class.perform_now(model_params: model.to_h,
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
    before do
      allow(object_client)
        .to receive(:update)
        .and_raise(Dor::Services::Client::ConflictResponse.new(response: '',
                                                               errors: [
                                                                 { 'title' => 'cocina roundtrip validation error ...' }
                                                               ]))
    end

    it 'reports error and will not retry' do
      described_class.perform_now(model_params: model.to_h,
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
    before do
      allow(object_client).to receive(:update).and_raise(StandardError, 'Something went wrong')
    end

    context 'with retries' do
      it 'retries' do
        expect do
          described_class.perform_now(model_params: model.to_h,
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
        described_class.perform_now(model_params: model.to_h,
                                    background_job_result: result,
                                    signed_ids:)
        expect(actual_result).to be_complete
        expect(actual_result.output[:errors]).to be_present
      end
    end
  end

  context 'when updating the current version' do
    let(:existing_version) { 2 }

    context 'when not already open, but openable' do
      before do
        allow(existing_version_status).to receive(:open?).and_return(false)
      end

      it 'opens the version, updates the metadata, purges the staged files, and marks the job complete for the druid' do
        described_class.perform_now(model_params: model.to_h,
                                    background_job_result: result,
                                    signed_ids:)
        expect(version_client).to have_received(:open).with(description: 'Update via sdr-api').once
        expect(object_client).to have_received(:update).with(params: model, skip_lock: true)
        expect(version_client).to have_received(:close)
        expect(actual_result).to be_complete
        expect(actual_result.output).to match({ druid: })
        expect(ActiveStorage::PurgeJob).to have_received(:perform_later).with(blob)
      end
    end

    context 'when already open' do
      before do
        allow(existing_version_status).to receive(:open?).and_return(true)
      end

      it 'opens the version, updates the metadata, purges the staged files, and marks the job complete for the druid' do
        described_class.perform_now(model_params: model.to_h,
                                    background_job_result: result,
                                    signed_ids:)
        expect(version_client).not_to have_received(:open)
        expect(object_client).to have_received(:update).with(params: model, skip_lock: true)
        expect(version_client).to have_received(:close)
        expect(actual_result).to be_complete
        expect(actual_result.output).to match({ druid: })
        expect(ActiveStorage::PurgeJob).to have_received(:perform_later).with(blob)
      end
    end
  end

  context 'when updating neither the current version nor the next version' do
    let(:update_version) { 5 }
    let(:existing_version) { 3 }

    it 'quits with an error' do
      described_class.perform_now(model_params: model.to_h,
                                  background_job_result: result,
                                  signed_ids:)

      err_title = 'Version conflict'
      err_detail = "The repository is on version '3' and " \
                   "you tried to create/update version '5'. Version is limited to 3 or 4."

      expect(actual_result).to be_complete
      expect(actual_result.output[:errors]).to eq [{ 'title' => err_title, 'detail' => err_detail }]
      expect(Honeybadger).to have_received(:notify).with("#{err_title}: #{err_detail}", {
                                                           existing_version: 3,
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
    let(:file) do # rubocop:disable RSpec/OverwritingSetup
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
          { type: 'sha1', digest: 'da39a3ee5e6b4b0d3255bfef95601890afd80709' },
          { type: 'md5', digest: 'd41d8cd98f00b204e9800998ecf8427e' }
        ],
        version: 2
      }
    end

    it 'sha1 and md5 digests are generated' do
      described_class.perform_now(model_params: model.to_h,
                                  background_job_result: result,
                                  signed_ids: {},
                                  globus_ids: { '00001.jp2' => 'globus://digest-test/00001.jp2' })
      expect(object_client).to have_received(:update).with(params: model, skip_lock: true)
      expect(actual_result).to be_complete
      expect(actual_result.output).to match({ druid: })
    end
  end
end
