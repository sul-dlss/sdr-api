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
  # @param [Boolean] start_workflow starts accessionWF if true; if false, opens/closes new version without accessioning
  # rubocop:disable Metrics/AbcSize
  # rubocop:disable Metrics/MethodLength
  def perform(model_params:, signed_ids:, background_job_result:, start_workflow: true)
    # Increment the try count
    background_job_result.try_count += 1
    background_job_result.processing!

    model = Cocina::Models.build(model_params.with_indifferent_access)

    object_client = Dor::Services::Client.object(model.externalIdentifier)
    existing = object_client.find

    unless [existing.version, existing.version + 1].include?(model.version)
      error_title = 'Version conflict'
      error_detail = "The repository is on version '#{existing.version}' for #{existing.externalIdentifier}. " \
                     'You may either: update the current version (for v1 registered, or a later open version); ' \
                     "or open a new version.  You tried to create/update version '#{model.version}'."

      Honeybadger.notify("#{error_title}: #{error_detail}")
      background_job_result.output = { errors: [title: error_title, detail: error_detail] }
      background_job_result.complete!

      return
    end

    object_client.update(params: model)

    background_job_result.output = { druid: model.externalIdentifier }

    versioning_params = { description: 'Update via sdr-api', significance: 'major' }
    StageFiles.stage(signed_ids, model.externalIdentifier) do
      if start_workflow
        # this will check openability, open/close a version as needed, and then kick off accessioning after
        # that regardless of whether a version was opened/closed.
        object_client.accession.start(versioning_params.merge(workflow: 'accessionWF'))
      elsif model.version == existing.version + 1
        # don't kick off accessioning, just create a new version where only metadata was updated
        object_client.version.open
        object_client.version.close(versioning_params.merge(start_accession: false))
      end
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
