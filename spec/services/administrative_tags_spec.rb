# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AdministrativeTags do
  subject(:administrative_tags) { described_class.for(type: type_uri, user: 'bergeraj') }

  describe '.for' do
    context 'with a book object' do
      let(:type_uri) { Cocina::Models::Vocab.book }

      it { is_expected.to eq(['Process : Content Type : Book (ltr)', 'Registered By : bergeraj']) }
    end

    context 'with a non-book object' do
      let(:type_uri) { Cocina::Models::Vocab.image }

      it { is_expected.to eq([]) }
    end
  end
end
