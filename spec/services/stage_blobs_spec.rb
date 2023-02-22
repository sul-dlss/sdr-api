# frozen_string_literal: true

require 'rails_helper'

RSpec.describe StageBlobs do
  describe '.stage' do
    let(:druid) { 'druid:bc123df4567' }
    let(:blob) do
      ActiveStorage::Blob.create!(key: 'tozuehlw6e8du20vn1xfzmiifyok',
                                  filename: 'file2.txt', byte_size: 10, checksum: 'f5nXiniiM+u/gexbNkOA/A==')
    end
    let(:signed_ids) do
      { 'file2.txt' => ActiveStorage.verifier.generate(blob.id, purpose: :blob_id) }
    end

    before do
      allow(described_class).to receive(:copy_files_to_staging)
      allow(described_class).to receive(:delete_from_active_storage)
    end

    context 'when signed IDs are supplied' do
      it 'copies files to staging, and cleans up active-storage and returns 1' do
        expect(described_class.stage(signed_ids, druid)).to be 1
        expect(described_class).to have_received(:copy_files_to_staging).once
        expect(described_class).to have_received(:delete_from_active_storage).once
      end
    end

    context 'when signed IDs are not supplied' do
      let(:signed_ids) { [] }

      it 'does nothing and returns 0' do
        expect(described_class.stage(signed_ids, druid)).to be 0
        expect(described_class).not_to have_received(:copy_files_to_staging)
        expect(described_class).not_to have_received(:delete_from_active_storage)
      end
    end
  end
end
