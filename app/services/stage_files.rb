# frozen_string_literal: true

# Moves files from the ActiveStorage to the staging mount
class StageFiles
  def self.stage(signed_ids, druid)
    blobs = Blobs.blobs_for(signed_ids)
    copy_files_to_staging(druid, blobs)
    yield
    delete_from_active_storage(blobs)
  end

  # Copy files to the staging directory from ActiveStorage for the assembly workflow
  def self.copy_files_to_staging(druid, blobs)
    dir = StagingDirectory.new(druid: druid, staging_location: Settings.staging_location)
    blobs.each do |blob|
      dir.copy_file(ActiveStorage::Blob.service.path_for(blob.key), blob.filename.to_s)
    end
  end
  private_class_method :copy_files_to_staging

  def self.delete_from_active_storage(blobs)
    # This is a purge_later so not worried about delete errors.
    blobs.each(&:purge_later)
  end
  private_class_method :delete_from_active_storage
end
