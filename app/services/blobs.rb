# frozen_string_literal: true

# Utility methods for getting ActiveStorage Blobs
class Blobs
  # @param [Array<Hash>] signed_ids for blobs
  # @return [Array<ActiveStorage::Blob>] corresponding blob objects
  def self.blobs_for(signed_ids)
    file_ids = signed_ids.map { |signed_id| ActiveStorage.verifier.verified(signed_id, purpose: :blob_id) }

    # This can raise ActiveRecord::RecordNotFound if one or more of the files don't exist
    ActiveStorage::Blob.find(file_ids)
  end
end
