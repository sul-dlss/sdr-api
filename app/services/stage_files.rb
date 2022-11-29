# frozen_string_literal: true

# Moves files from the ActiveStorage to the staging mount
class StageFiles
  def self.stage(signed_ids, druid)
    # Skip side effects if no signed IDs provided
    return yield if signed_ids.empty?

    @dir = StagingDirectory.new(druid: druid, staging_location: Settings.staging_location)

    blobs = Blobs.blobs_for(signed_ids)
    if blobs.empty?
      copy_globus(signed_ids)
    else
      copy_blobs(blobs)
    end
    yield
  end

  def self.copy_blobs(blobs)
    copy_files_to_staging(blobs)
    delete_from_active_storage(blobs.values)
  end
  private_class_method :copy_blobs

  def self.copy_globus(signed_ids)
    signed_ids.select { |_key, value| value&.match?(%r{^globus://}) }.each do |filename, globus_path|
      @dir.copy_file(globus_path.gsub('globus://', Settings.globus_location), filename)
    end
  end
  private_class_method :copy_globus

  # Copy files to the staging directory from ActiveStorage for the assembly workflow
  def self.copy_files_to_staging(blobs)
    blobs.each do |filename, blob|
      @dir.copy_file(ActiveStorage::Blob.service.path_for(blob.key), filename)
    end
  end
  private_class_method :copy_files_to_staging

  def self.delete_from_active_storage(blobs)
    # This is a purge_later so not worried about delete errors.
    blobs.each(&:purge_later)
  end
  private_class_method :delete_from_active_storage
end
