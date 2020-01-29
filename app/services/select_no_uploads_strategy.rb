# frozen_string_literal: true

# A strategy class that selects no uploads: a null strategy, if you will. Used
# by the `DirectUploadsSweeper`
class SelectNoUploadsStrategy
  # @return [ActiveRecord::Relation]
  def self.select
    new.select
  end

  # @return [ActiveRecord::Relation]
  def select
    active_record_class.none
  end

  private

  def active_record_class
    ActiveStorage::Blob
  end
end
