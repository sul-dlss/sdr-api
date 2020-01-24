# frozen_string_literal: true

# Builds the contentMetadata xml
class ContentMetadataGenerator
  # @param [String] druid the object identifier
  # @param [Hash<String,String>] file_names a map of short filenames to of full paths to the files
  # @param [Array<Hash>] filesets a representation of the cocina fileset models
  def self.generate(druid:, file_names:, filesets:)
    new(file_names: file_names, druid: druid, filesets: filesets).generate
  end

  def initialize(file_names:, druid:, filesets:)
    @file_names = file_names
    @druid = druid
    @filesets = filesets
  end

  def generate
    @xml_doc = Nokogiri::XML('<contentMetadata />')
    @xml_doc.root['objectId'] = druid.to_s
    @xml_doc.root['type'] = Assembly::ContentMetadata.object_level_type(:simple_book)

    assembly_filesets.each_with_index do |(cocina_fileset, assembly_fileset), index|
      # each resource type description gets its own incrementing counter
      resource_type_counters[assembly_fileset.resource_type_description] += 1
      @xml_doc.root.add_child create_resource_node(cocina_fileset, assembly_fileset, index + 1)
    end

    @xml_doc.to_xml
  end

  private

  attr_reader :file_names, :druid, :filesets

  def common_path
    @common_path ||= Assembly::ContentMetadata.send(:find_common_path, object_files.values)
  end

  # @return [Array] A array of tuples of cocina fileset and assembly fileset
  def assembly_filesets
    filesets.map do |fs|
      resource_files = fs.fetch('structural').fetch('hasMember')
                         .map { |file| object_files.fetch(file.fetch('filename')) }
      [fs, Assembly::ContentMetadata::FileSet.new(resource_files: resource_files, style: :simple_book)]
    end
  end

  def resource_type_counters
    @resource_type_counters ||= Hash.new(0)
  end

  # @param [String] id
  # @param [Hash] cocina_file
  # @return [Nokogiri::XML::Node] the file node
  def create_file_node(id, cocina_file)
    Nokogiri::XML::Node.new('file', @xml_doc).tap do |file_node|
      file_node['id'] = id
      file_node['publish'] = publish_attr(cocina_file)
      file_node['shelve'] = shelve_attr(cocina_file)
      file_node['preserve'] = preserve_attr(cocina_file)
      cocina_file.fetch('hasMessageDigests', []).each do |message_digest|
        file_node.add_child(create_checksum_node(message_digest['type'], message_digest['digest']))
      end
    end
  end

  def publish_attr(cocina_file)
    cocina_file.fetch('access').fetch('access') == 'dark' ? 'no' : 'yes'
  end

  def shelve_attr(cocina_file)
    cocina_file.fetch('administrative').fetch('shelve') ? 'yes' : 'no'
  end

  def preserve_attr(cocina_file)
    cocina_file.fetch('administrative').fetch('sdrPreserve') ? 'yes' : 'no'
  end

  def create_checksum_node(algorithm, digest)
    Nokogiri::XML::Node.new('checksum', @xml_doc).tap do |checksum_node|
      checksum_node['type'] = algorithm
      checksum_node.content = digest
    end
  end

  # @param [Hash] cocina_fileset the cocina fileset
  # @param [Assembly::ContentMetadata::FileSet] assembly_fileset
  # @param [Integer] sequence
  def create_resource_node(cocina_fileset, assembly_fileset, sequence)
    pid = druid.gsub('druid:', '') # remove druid prefix when creating IDs

    Nokogiri::XML::Node.new('resource', @xml_doc).tap do |resource|
      resource['id'] = "#{pid}_#{sequence}"
      resource['sequence'] = sequence
      resource['type'] = assembly_fileset.resource_type_description

      resource.add_child(Nokogiri::XML::Node.new('label', @xml_doc)
        .tap { |c| c.content = fileset_label(assembly_fileset) })
      create_file_nodes(resource, cocina_fileset, assembly_fileset)
    end
  end

  def create_file_nodes(resource, cocina_fileset, assembly_fileset)
    assembly_fileset.files.each do |assembly_file|
      id = assembly_file.file_id(common_path: common_path, flatten_folder_structure: false)
      cocina_file = cocina_fileset.fetch('structural').fetch('hasMember')
                                  .find { |file| file.fetch('filename') == id }
      resource.add_child(create_file_node(id, cocina_file))
    end
  end

  def fileset_label(assembly_fileset)
    resource_type = assembly_fileset.resource_type_description.capitalize
    default_label = "#{resource_type} #{resource_type_counters[assembly_fileset.resource_type_description]}"

    # but if one of the files has a label, use it instead
    assembly_fileset.label_from_file(default: default_label)
  end

  # @return [Hash<String,Assembly::ObjectFile>]
  def object_files
    @object_files ||= file_names.each_with_object({}) do |(short, file_path), out|
      out[short] = Assembly::ObjectFile.new(file_path)
    end
  end
end
