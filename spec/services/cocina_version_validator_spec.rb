# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CocinaVersionValidator do
  context 'when identical versions' do
    it 'returns true' do
      expect(described_class.valid?(Cocina::Models::VERSION)).to be true
      expect(described_class.valid?('1.1.1', cocina_version: '1.1.1')).to be true
    end
  end

  context 'when identical major and minor versions' do
    it 'returns true' do
      expect(described_class.valid?('1.1.1', cocina_version: '1.1.2')).to be true
    end
  end

  context 'when different major versions' do
    it 'returns false' do
      expect(described_class.valid?('1.1.1', cocina_version: '2.1.1')).to be false
    end
  end

  context 'when different minor versions' do
    it 'returns false' do
      expect(described_class.valid?('1.1.1', cocina_version: '1.2.1')).to be false
    end
  end
end
