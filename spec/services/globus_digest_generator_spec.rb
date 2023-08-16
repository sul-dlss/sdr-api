# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GlobusDigestGenerator do
  let(:structural) do
    {
      'isMemberOf' => ['druid:fg123hj4567'],
      'contains' => [
        {
          'type' => Cocina::Models::FileSetType.file,
          'externalIdentifier' => '999',
          'label' => 'Page 1',
          'structural' => {
            'contains' => [
              {
                'type' => Cocina::Models::ObjectType.file,
                'filename' => '00001.jp2',
                'label' => '00001.jp2',
                'hasMessageDigests' => [],
                'externalIdentifier' => 'abc123',
                'version' => 1
              },
              {
                'type' => Cocina::Models::ObjectType.file,
                'filename' => '00002.jp2',
                'label' => '00002.jp2',
                'hasMessageDigests' => [],
                'externalIdentifier' => 'abc123',
                'version' => 1
              },
              {
                'type' => Cocina::Models::ObjectType.file,
                'filename' => '00003.jp2',
                'label' => '00002.jp2',
                'hasMessageDigests' => [
                  {
                    'type' => 'sha1',
                    'digest' => 'not-a-real-sha1'
                  },
                  {
                    'type' => 'md5',
                    'digest' => 'not-a-real-md5'
                  }
                ],
                'externalIdentifier' => 'abc123',
                'version' => 1
              }
            ]
          },
          'version' => 1
        }
      ]
    }
  end

  let(:dro) { build(:dro, id: 'druid:bc999dg9999').new(structural:) }

  describe '#generate' do
    let(:new_dro) { described_class.generate(cocina: dro, globus_ids:) }
    let(:files) { new_dro.structural.contains[0].structural.contains }
    let(:globus_ids) do
      {
        '00001.jp2' => 'globus://test/00001.jp2',
        '00002.jp2' => 'globus://test/00002.jp2'
      }
    end

    before do
      FileUtils.rm_rf('tmp/globus/test')
      FileUtils.mkdir_p('tmp/globus/test')
      FileUtils.cp_r('spec/fixtures/.', 'tmp/globus/test')
    end

    it 'populates missing digests' do
      expect(files[0].hasMessageDigests[0].type).to eq 'sha1'
      expect(files[0].hasMessageDigests[0].digest).to eq 'da39a3ee5e6b4b0d3255bfef95601890afd80709'
      expect(files[0].hasMessageDigests[1].type).to eq 'md5'
      expect(files[0].hasMessageDigests[1].digest).to eq 'd41d8cd98f00b204e9800998ecf8427e'

      expect(files[1].hasMessageDigests[0].type).to eq 'sha1'
      expect(files[1].hasMessageDigests[0].digest).to eq 'da39a3ee5e6b4b0d3255bfef95601890afd80709'
      expect(files[1].hasMessageDigests[1].type).to eq 'md5'
      expect(files[1].hasMessageDigests[1].digest).to eq 'd41d8cd98f00b204e9800998ecf8427e'
    end

    it 'leaves pre-existing digests alone' do
      expect(files[2].hasMessageDigests[0].type).to eq 'sha1'
      expect(files[2].hasMessageDigests[0].digest).to eq 'not-a-real-sha1'
      expect(files[2].hasMessageDigests[1].type).to eq 'md5'
      expect(files[2].hasMessageDigests[1].digest).to eq 'not-a-real-md5'
    end
  end
end
