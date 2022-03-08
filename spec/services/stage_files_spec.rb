# frozen_string_literal: true

require 'rails_helper'

RSpec.describe StageFiles do
  describe '.stage' do
    let(:druid) { 'druid:bc123df4567' }

    before do
      allow(Blobs).to receive(:blobs_for)
      allow(described_class).to receive(:copy_files_to_staging)
      allow(described_class).to receive(:delete_from_active_storage)
    end

    context 'when signed IDs are supplied' do
      let(:signed_ids) { %w[iamasignedid andsoami] }

      it 'copies files to staging, yields, and cleans up active-storage' do
        expect { |b| described_class.stage(signed_ids, druid, &b) }.to yield_control.once
        expect(described_class).to have_received(:copy_files_to_staging).once
        expect(described_class).to have_received(:delete_from_active_storage).once
      end
    end

    context 'when signed IDs are not supplied' do
      let(:signed_ids) { [] }

      it 'yields and does nothing else' do
        expect { |b| described_class.stage(signed_ids, druid, &b) }.to yield_control.once
        expect(described_class).not_to have_received(:copy_files_to_staging)
        expect(described_class).not_to have_received(:delete_from_active_storage)
      end
    end
  end
end
