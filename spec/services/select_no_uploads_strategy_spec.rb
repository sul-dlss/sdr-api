# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SelectNoUploadsStrategy do
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

  describe '#select' do
    subject(:selection) { strategy.select }

    it { is_expected.to be_kind_of(ActiveRecord::Relation) }

    it 'returns an empty set' do
      expect(selection.size).to be_zero
    end
  end
end
