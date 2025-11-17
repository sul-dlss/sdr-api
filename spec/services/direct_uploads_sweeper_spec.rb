# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DirectUploadsSweeper do
  subject(:sweeper) { described_class.new }

  let(:default_strategy) { sweeper.send(:default_selection_strategy) }
  let(:mock_strategy) { double }

  describe '#initialize' do
    it 'sets a default selection strategy' do
      expect(sweeper.strategy).to eq(default_strategy)
    end

    context 'with `strategy:` keyword argument' do
      subject(:sweeper) { described_class.new(strategy: mock_strategy) }

      it 'allows injection of a selection strategy' do
        expect(sweeper.strategy).to eq(mock_strategy)
      end
    end
  end

  describe '#strategy=' do
    before do
      sweeper.strategy = mock_strategy
    end

    it 'allows injection of a selection strategy' do
      expect(sweeper.strategy).to eq(mock_strategy)
    end
  end

  describe '#sweep' do
    let(:mock_relation) { instance_double(ActiveRecord::Relation, find_each: nil) }
    let(:mock_strategy) { double(select: mock_relation) }

    before do
      # Use mock strategy to test #sweep behavior because it is easier to mock,
      # and the default selection strategy is tested elsewhere
      sweeper.strategy = mock_strategy
    end

    it 'iterates over the selected records and purges them' do
      sweeper.sweep
      expect(sweeper.strategy).to have_received(:select).once
      expect(mock_relation).to have_received(:find_each).with(batch_size: anything, &:purge_later).once
    end
  end
end
