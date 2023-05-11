# frozen_string_literal: true

# Processes a deposit, namely shipping files to assembly NFS mount and starting the workflow
# If an error is raised, Sidekiq will retry up to a configured number of retries.
# Above that, it will exit and provide the error message in the background_job_result.
class UpdateJob < ApplicationJob
  queue_as :default
  attr_accessor :start_workflow

  # Note that deciding when to stop retrying is handled below. Hence, not providing additional retry configuration
  # for Sidekiq.

  # @param [Hash] model_params
  # @param [Hash] filename, signed_ids for the blobs
  # @param [Hash] filename, globus_ids for the staged Globus files
  # @param [BackgroundJobResult] background_job_result
  # @param [Boolean] start_workflow starts accessionWF if true; if false, opens/closes new version without accessioning
  # @param [String] version_description
  # rubocop:disable Metrics/AbcSize
  # rubocop:disable Metrics/MethodLength
  # rubocop:disable  Metrics/ParameterLists
  def perform(model_params:,
              background_job_result:,
              signed_ids: {},
              globus_ids: {},
              start_workflow: true,
              version_description: nil)
    @start_workflow = start_workflow
    # Increment the try count
    background_job_result.try_count += 1
    background_job_result.processing!

    model = Cocina::Models.build(model_params.with_indifferent_access)

    object_client = Dor::Services::Client.object(model.externalIdentifier)
    existing = object_client.find
    allowed_versions = [existing.version, existing.version + 1]
    unless allowed_versions.include?(model.version)
      error_title = 'Version conflict'
      error_detail = "The repository is on version '#{existing.version}' and you " \
                     "tried to create/update version '#{model.version}'. " \
                     "Version is limited to #{allowed_versions.join(' or ')}."

      Honeybadger.notify("#{error_title}: #{error_detail}",
                         { external_identifier: existing.externalIdentifier,
                           current_version: existing.version,
                           provided_version: model.version })
      background_job_result.output = { errors: [title: error_title, detail: error_detail] }
      background_job_result.complete!

      return
    end

    # globus deposits may not have digests yet and they need to be generated before staging (copy)
    model = GlobusDigestGenerator.generate(cocina: model, globus_ids:)

    # not using a lock here since all model params are being provided rather than updating retrieved params.
    object_client.update(params: model, skip_lock: true)

    background_job_result.output = { druid: model.externalIdentifier }

    versioning_params = { description: version_description || 'Update via sdr-api', significance: 'major' }

    StageBlobs.stage(signed_ids, model.externalIdentifier)
    StageGlobus.stage(globus_ids, model.externalIdentifier)

    version_or_accession(object_client, model, existing, versioning_params)

    background_job_result.complete!
  rescue Dor::Services::Client::BadRequestError => e
    # report as error and do not retry
    error = { errors: [title: 'HTTP 400 (Bad Request) from dor-services-app', message: e.message] }
    background_job_result.output = background_job_result.output.merge(error)
    background_job_result.complete!
  rescue Dor::Services::Client::ConflictResponse => e
    # RoundtripValidationError for cocina uses HTTP 409 as status
    # report as error and do not retry
    error = { errors: [title: 'HTTP 409 (Conflict) from dor-services-app', message: e.message] }
    background_job_result.output = background_job_result.output.merge(error)
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
  # rubocop:enable Metrics/ParameterLists
  # rubocop:enable Metrics/AbcSize
  # rubocop:enable Metrics/MethodLength

  def version_or_accession(object_client, model, existing, versioning_params)
    if start_workflow
      # this will check openability, open/close a version as needed, and then kick off accessioning after
      # that regardless of whether a version was opened/closed.
      object_client.accession.start(versioning_params.merge(workflow: 'accessionWF'))
    elsif model.version == existing.version + 1
      # don't kick off accessioning, just create a new version where only metadata was updated
      object_client.version.open(versioning_params)
      object_client.version.close(versioning_params.merge(start_accession: false))
    end
  end
end
