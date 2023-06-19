# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SelectOutdatedUploadsStrategy do
  subject(:strategy) { described_class.new }

  describe '.select' do
    before do
      allow(described_class).to receive(:new).and_return(mock_instance)
    end

    let(:mock_instance) { instance_double(described_class, select: nil) }

    it 'invokes #select on a new instance of the class' do
      described_class.select
      expect(mock_instance).to have_received(:select).once
    end
  end

  describe '#initialize' do
    subject(:default_days_ago) { strategy.send(:default_days_ago) }

    it 'sets a default days_ago attr' do
      expect(strategy.days_ago.to_date).to eq(default_days_ago.days.ago.to_date)
    end

    context 'when injecting a days_ago attr' do
      let(:strategy) { described_class.new(days_ago:) }
      let(:days_ago) { 2 }

      it 'sets the days_ago attr to a normalized time object' do
        expect(strategy.days_ago.to_date).not_to eq(default_days_ago.days.ago.to_date)
      end
    end
  end

  describe '#select' do
    subject(:selection) { strategy.select }

    let(:old_28days_ago) { 28.days.ago }
    let(:old_14days_ago) { 14.days.ago }
    let!(:outdated28_upload) { create(:active_storage_blob, created_at: old_28days_ago) }
    let!(:outdated14_upload) { create(:active_storage_blob, created_at: old_14days_ago) }

    it { is_expected.to be_a(ActiveRecord::Relation) }

    it 'returns both outdated uploads and none of the current ones' do
      expect(selection.size).to eq(2)
      expect(selection).to contain_exactly(outdated28_upload, outdated14_upload)
    end
  end
end
