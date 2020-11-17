# frozen_string_literal: true

# Processes a deposit, namely shipping files to assembly NFS mount and starting the workflow
# If an error is raised, Sidekiq will retry up to a configured number of retries.
# Above that, it will exit and provide the error message in the background_job_result.
class UpdateJob < ApplicationJob
  queue_as :default
  # Note that deciding when to stop retrying is handled below. Hence, not providing additional retry configuration
  # for Sidekiq.

  # @param [Hash] model_params
  # @param [Array<String>] signed_ids for the blobs
  # @param [BackgroundJobResult] background_job_result
  # rubocop:disable Metrics/AbcSize
  # rubocop:disable Metrics/MethodLength
  def perform(model_params:, signed_ids:, background_job_result:)
    # Increment the try count
    background_job_result.try_count += 1
    background_job_result.processing!

    model = Cocina::Models::DRO.new(model_params)

    object_client = Dor::Services::Client.object(model.externalIdentifier)
    existing = object_client.find
    if existing.version >= model.version
      background_job_result.output = {
        errors: [
          title: 'Version conflict',
          detail: "The repository already has a version '#{existing.version}' for " \
                  "#{existing.externalIdentifier}, and you provided '#{model.version}'"
        ]
      }
      background_job_result.complete!
      return
    end

    object_client.version.open
    object_client.update(params: model)

    background_job_result.output = { druid: model.externalIdentifier }

    StageFiles.stage(signed_ids, model.externalIdentifier) do
      object_client.version.close(description: 'Update via sdr-api', significance: 'major')
    end

    background_job_result.complete!
  rescue StandardError => e
    # This causes Sidekiq to retry.
    if background_job_result.try_count < Settings.sdr_api.ingest_retries
      background_job_result.pending!
      raise
    end

    # Otherwise return an error on background_job_result but exit cleanly.
    background_job_result.output = background_job_result.output.merge({ errors: [title: 'All retries failed',
                                                                                 message: e.message] })
    background_job_result.complete!
  end
  # rubocop:enable Metrics/AbcSize
  # rubocop:enable Metrics/MethodLength
end
