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
      let(:strategy) { described_class.new(days_ago: days_ago) }
      let(:days_ago) { 2 }

      it 'sets the days_ago attr to a normalized time object' do
        expect(strategy.days_ago.to_date).not_to eq(default_days_ago.days.ago.to_date)
      end
    end
  end

  # rubocop:disable RSpec/LetSetup
  describe '#select' do
    subject(:selection) { strategy.select }

    let(:old_days_ago1) { 28.days.ago }
    let(:old_days_ago2) { 14.days.ago }
    let!(:outdated_upload1) { create(:active_storage_blob, created_at: old_days_ago1) }
    let!(:outdated_upload2) { create(:active_storage_blob, created_at: old_days_ago2) }
    let!(:current_upload1) { create(:active_storage_blob) }
    let!(:current_upload2) { create(:active_storage_blob) }
    let!(:current_upload3) { create(:active_storage_blob) }

    it { is_expected.to be_a(ActiveRecord::Relation) }

    it 'returns both outdated uploads and none of the current ones' do
      expect(selection.size).to eq(2)
      expect(selection).to match_array([outdated_upload1, outdated_upload2])
    end
  end
  # rubocop:enable RSpec/LetSetup
end
