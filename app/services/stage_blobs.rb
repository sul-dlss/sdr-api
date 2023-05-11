# frozen_string_literal: true

# Moves files from the ActiveStorage to the staging mount
# @param [Hash] signed_ids a mapping of filenames to ActiveStorage signed id
# @param [String] druid
# @return [Integer] the number of files staged
class StageBlobs
  def self.stage(signed_ids, druid)
    # Skip side effects if no signed IDs provided
    return 0 if signed_ids.empty?

    blobs = Blobs.blobs_for(signed_ids)
    copy_files_to_staging(druid, blobs)
    delete_from_active_storage(blobs.values)

    blobs.size
  end

  # Copy files to the staging directory from ActiveStorage for the assembly workflow
  def self.copy_files_to_staging(druid, blobs)
    dir = StagingDirectory.new(druid:, staging_location: Settings.staging_location)
    blobs.each do |filename, blob|
      dir.copy_file(ActiveStorage::Blob.service.path_for(blob.key), filename)
    end
  end
  private_class_method :copy_files_to_staging

  def self.delete_from_active_storage(blobs)
    # This is a purge_later so not worried about delete errors.
    blobs.each(&:purge_later)
  end
  private_class_method :delete_from_active_storage
end
