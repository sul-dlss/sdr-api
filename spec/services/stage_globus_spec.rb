# frozen_string_literal: true

require 'rails_helper'

RSpec.describe StageGlobus do
  describe '.stage' do
    let(:druid) { 'druid:bc123df4567' }
    let(:blob) do
      ActiveStorage::Blob.create!(key: 'tozuehlw6e8du20vn1xfzmiifyok',
                                  filename: 'file2.txt', byte_size: 10, checksum: 'f5nXiniiM+u/gexbNkOA/A==')
    end
    let(:globus_ids) do
      { 'file2.txt' => 'globus://some/file/path/file2.txt' }
    end
    let(:dir) { StagingDirectory.new(druid: druid, staging_location: Settings.staging_location) }
    let(:assembly_dir) { 'tmp/assembly/bc/123/df/4567/bc123df4567' }

    before do
      FileUtils.rm_rf('tmp/globus')
      FileUtils.mkdir_p('tmp/globus/some/file/path')
      File.write('tmp/globus/some/file/path/file2.txt', 'HELLO')
    end

    context 'when globus IDs are supplied' do
      it 'copies files to staging, yields, and cleans up active-storage' do
        expect { |b| described_class.stage(globus_ids, druid, &b) }.to yield_control.once
        expect(File.read("#{assembly_dir}/content/file2.txt")).to eq 'HELLO'
      end
    end

    context 'when signed IDs are not supplied' do
      let(:globus_ids) { [] }

      it 'yields and does nothing else' do
        expect { |b| described_class.stage(globus_ids, druid, &b) }.to yield_control.once
      end
    end
  end
end