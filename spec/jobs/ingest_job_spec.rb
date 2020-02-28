# frozen_string_literal: true

require 'rails_helper'

RSpec.describe IngestJob, type: :job do
  subject(:run) do
    described_class.perform_now(druid: druid, filesets: filesets, background_job_result: result)
  end

  let(:result) { create(:background_job_result) }
  let(:druid) { 'druid:bc123de5678' }
  let(:client) { instance_double(Dor::Workflow::Client, create_workflow_by_name: true) }
  let(:blob) do
    ActiveStorage::Blob.create!(key: 'tozuehlw6e8du20vn1xfzmiifyok',
                                filename: 'file2.txt', byte_size: 10, checksum: 'fffff')
  end
  let(:file_id) do
    ActiveStorage.verifier.generate(blob.id, purpose: :blob_id)
  end

  let(:file) do
    {
      'type' => 'http://cocina.sul.stanford.edu/models/file.jsonld',
      'filename' => 'file2.txt',
      'label' => 'file2.txt',
      'hasMimeType' => 'text/plain',
      'externalIdentifier' => file_id,
      'administrative' => {
        'sdrPreserve' => true,
        'shelve' => true
      },
      'access' => {
        'access' => 'citation-only'
      }
    }
  end

  let(:filesets) do
    [
      {
        'type' => 'http://cocina.sul.stanford.edu/models/fileset.jsonld',
        'label' => 'Page 1',
        'structural' => { 'contains' => [file] }
      }
    ]
  end

  let(:assembly_dir) { 'tmp/assembly/bc/123/de/5678/bc123de5678' }

  before do
    FileUtils.rm_r('tmp/assembly/bc') if File.exist?('tmp/assembly/bc')
    FileUtils.mkdir_p('tmp/storage/to/zu')
    File.open('tmp/storage/to/zu/tozuehlw6e8du20vn1xfzmiifyok', 'w') do |f|
      f.write 'HELLO'
    end
    allow(Dor::Workflow::Client).to receive(:new).and_return(client)
  end

  it 'creates a workflow' do
    run
    expect(File.read("#{assembly_dir}/content/file2.txt")).to eq 'HELLO'
    expect(client).to have_received(:create_workflow_by_name).with(druid, 'accessionWF', version: 1, lane_id: 'low')
    expect(result).to be_complete
  end
end
