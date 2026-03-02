# frozen_string_literal: true

# Sweep direct uploads per an injected strategy
class DirectUploadsSweeper
  # Use a public accessor to allow for interactive injection of the strategy
  # dependency
  attr_accessor :strategy

  # @param [#select] strategy a database selection strategy
  def initialize(strategy: default_selection_strategy)
    @strategy = strategy
  end

  # @return void
  def sweep
    # NOTE: Prefer `#purge_later` over `#purge` and `#destroy`. `#destroy`
    #       only deletes database entries, whereas `#purge*` also removes
    #       files on the filesystem. The purge operation itself may be a slow
    #       operation, so run it in the background via `#purge_later` per
    #       https://github.com/rails/rails/blob/v6.0.2.1/activestorage/app/models/active_storage/blob.rb#L224-L245
    count = 0
    strategy
      .select
      .find_each(batch_size: Settings.sdr_api.blob_batch_size) do |upload|
      upload.purge_later
      count += 1
    end
    Rails.logger.info("Queued #{count} uploads for purging.")
  end

  private

  def default_selection_strategy
    SelectNoUploadsStrategy
  end
end
