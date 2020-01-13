# frozen_string_literal: true

# Builds the contentMetadata xml
class ContentMetadataGenerator
  # @param [String] druid the object identifier
  # @param [Array<String>] file_names a list of full paths to the files
  def self.generate(druid:, file_names:)
    new(file_names: file_names, druid: druid).generate
  end

  def initialize(file_names:, druid:)
    @file_names = file_names
    @druid = druid
  end

  def generate
    Assembly::ContentMetadata.create_content_metadata(cm_params)
  end

  private

  attr_reader :file_names, :druid

  def cm_params
    {
      druid: druid,
      objects: object_files,
      file_attributes: file_attributes,
      add_file_attributes: true,
      add_exif: false,
      bundle: :filename,
      style: :simple_book
    }
  end

  def object_files
    file_names.map { |file_name| Assembly::ObjectFile.new(file_name) }
  end

  # default publish/preserve/shelve attributes by mimetype
  #
  # CAUTION: this is an approach that will probably only work for the GoogleBooks
  # work cycle because it does not publish or shelve .xml or .md5 files. We
  # should in the future get this data from the structural metadata itself (e.g. filesets).
  # rubocop:disable  Metrics/MethodLength
  def file_attributes
    {
      'image/jp2' => {
        publish: 'yes',
        shelve: 'yes',
        preserve: 'yes'
      },
      'image/tiff' => {
        publish: 'no',
        shelve: 'no',
        preserve: 'yes'
      },
      'application/xml' => {
        publish: 'no',
        shelve: 'no',
        preserve: 'yes'
      },
      'default' => {
        publish: 'no',
        shelve: 'no',
        preserve: 'yes'
      }
    }
  end
  # rubocop:enable  Metrics/MethodLength
end
