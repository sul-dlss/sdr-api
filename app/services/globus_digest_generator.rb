# frozen_string_literal: true

# GlobusDigestGenerator
#
# Add digests to Globus DROs if the files currently lack them. Existing files
# will not be overwritten.
class GlobusDigestGenerator
  # @param [Cocina::Model] cocina a DRO to add digests to
  # @param [Hash] globus_ids a mapping of filenames to their location on disk
  # @return [Cocina::Model] a new Cocina object with (potentially) new digests
  def self.generate(cocina:, globus_ids:)
    new(cocina:, globus_ids:).generate
  end

  def initialize(cocina:, globus_ids:)
    @cocina = cocina
    @globus_ids = globus_ids
  end

  def generate
    return cocina if !cocina.dro? || globus_ids.blank?

    props = cocina.to_h
    props[:structural] = generate_filesets(props[:structural])

    if cocina.is_a? Cocina::Models::RequestDRO
      Cocina::Models.build_request(props)
    else
      Cocina::Models.build(props)
    end
  end

  private

  attr_reader :cocina, :globus_ids

  def generate_filesets(filesets)
    filesets[:contains] = filesets[:contains].map do |fileset|
      generate_files(fileset)
    end

    filesets
  end

  def generate_files(fileset)
    fileset[:structural][:contains] = fileset[:structural][:contains].map do |file|
      generate_digests(file)
    end

    fileset
  end

  def generate_digests(file)
    # only generate digests for a file if it doesn't have any
    if file[:hasMessageDigests].blank? && globus_ids.key?(file[:filename])
      file_path = globus_ids[file[:filename]].sub(%r{^globus://}, Settings.globus_location)
      file[:hasMessageDigests] = [
        { type: 'md5', digest: Digest::MD5.file(file_path).hexdigest },
        { type: 'sha1', digest: Digest::SHA1.file(file_path).hexdigest }
      ]
    end

    file
  end
end
