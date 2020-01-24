# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ContentMetadataGenerator do
  subject(:generate) do
    described_class.generate(druid: druid,
                             file_names: {
                               '00001.html' => 'spec/fixtures/00001.html',
                               '00001.jp2' => 'spec/fixtures/00001.jp2',
                               '00002.html' => 'spec/fixtures/00002.html',
                               '00002.jp2' => 'spec/fixtures/00002.jp2'
                             },
                             filesets: filesets)
  end

  let(:druid) { 'druid:bc123de5678' }

  let(:file1) do
    {
      'type' => 'http://cocina.sul.stanford.edu/models/file.jsonld',
      'filename' => '00001.html',
      'label' => '00001.html',
      'hasMimeType' => 'text/html',
      'administrative' => {
        'sdrPreserve' => true,
        'shelve' => false
      },
      'access' => {
        'access' => 'dark'
      },
      'hasMessageDigests' => [
        {
          'type' => 'sha1',
          'digest' => 'cb19c405f8242d1f9a0a6180122dfb69e1d6e4c7'
        },
        {
          'type' => 'md5',
          'digest' => 'e6d52da47a5ade91ae31227b978fb023'
        }

      ]
    }
  end

  let(:file2) do
    {
      'type' => 'http://cocina.sul.stanford.edu/models/file.jsonld',
      'filename' => '00001.jp2',
      'label' => '00001.jp2',
      'hasMimeType' => 'image/jp2',
      'administrative' => {
        'sdrPreserve' => true,
        'shelve' => true
      },
      'access' => {
        'access' => 'stanford-only'
      }
    }
  end

  let(:file3) do
    {
      'type' => 'http://cocina.sul.stanford.edu/models/file.jsonld',
      'filename' => '00002.html',
      'label' => '00002.html',
      'hasMimeType' => 'text/html',
      'administrative' => {
        'sdrPreserve' => true,
        'shelve' => false
      },
      'access' => {
        'access' => 'world'
      }
    }
  end

  let(:file4) do
    {
      'type' => 'http://cocina.sul.stanford.edu/models/file.jsonld',
      'filename' => '00002.jp2',
      'label' => '00002.jp2',
      'hasMimeType' => 'image/jp2',
      'administrative' => {
        'sdrPreserve' => true,
        'shelve' => true
      },
      'access' => {
        'access' => 'world'
      }
    }
  end

  let(:filesets) do
    [
      {
        'type' => 'http://cocina.sul.stanford.edu/models/fileset.jsonld',
        'label' => 'Page 1',
        'structural' => { 'hasMember' => [file1, file2] }
      },
      {
        'type' => 'http://cocina.sul.stanford.edu/models/fileset.jsonld',
        'label' => 'Page 2',
        'structural' => { 'hasMember' => [file3, file4] }
      }
    ]
  end

  it 'generates contentMetadata.xml' do
    expect(generate).to be_equivalent_to '<?xml version="1.0"?>
       <contentMetadata objectId="druid:bc123de5678" type="book">
         <resource id="bc123de5678_1" sequence="1" type="object">
           <label>Object 1</label>
           <file id="00001.html" preserve="yes" publish="no" shelve="no">
             <checksum type="sha1">cb19c405f8242d1f9a0a6180122dfb69e1d6e4c7</checksum>
             <checksum type="md5">e6d52da47a5ade91ae31227b978fb023</checksum>
           </file>
           <file id="00001.jp2" preserve="yes" publish="yes" shelve="yes"/>
         </resource>
         <resource id="bc123de5678_2" sequence="2" type="object">
           <label>Object 2</label>
           <file id="00002.html" preserve="yes" publish="yes" shelve="no"/>
           <file id="00002.jp2" preserve="yes" publish="yes" shelve="yes"/>
         </resource>
       </contentMetadata>'
  end
end
