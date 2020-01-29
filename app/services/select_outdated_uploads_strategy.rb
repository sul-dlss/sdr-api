# frozen_string_literal: true

# A strategy class that selects uploads older than a given or configured date.
# Used by the `DirectUploadsSweeper`
class SelectOutdatedUploadsStrategy
  # @param [Integer] days_ago an integer representing the number of days before which uploads will be selected
  # @return [ActiveRecord::Relation]
  def self.select(days_ago: default_days_ago)
    new(days_ago: days_ago).select
  end

  # @return [Integer]
  def self.default_days_ago
    Settings.sdr_api.days_after_which_to_remove_uploads
  end

  attr_reader :days_ago

  # @param [Integer] days_ago an integer representing the number of days ago before which uploads will be selected
  def initialize(days_ago: default_days_ago)
    @days_ago = days_ago.days.ago
  end

  # @return [ActiveRecord::Relation]
  def select
    active_record_class.where(
      active_record_class.arel_table[:created_at].lt(
        days_ago
      )
    )
  end

  private

  def default_days_ago
    self.class.default_days_ago
  end

  def active_record_class
    ActiveStorage::Blob
  end
end
