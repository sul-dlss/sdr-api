# frozen_string_literal: true

# Utility methods for getting ActiveStorage Blobs
class Blobs
  # @param [Hash] filename, signed_ids for blobs
  # @return [Hash] filename, ActiveStorage::Blob for corresponding blob objects
  def self.blobs_for(signed_ids)
    {}.tap do |blob_hash|
      signed_ids.each do |filename, signed_id|
        file_id = ActiveStorage.verifier.verified(signed_id, purpose: :blob_id)
        # This can raise ActiveRecord::RecordNotFound if file does not exist
        blob_hash[filename] = ActiveStorage::Blob.find(file_id)
      end
    end
  end
end
