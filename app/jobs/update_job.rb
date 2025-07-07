# frozen_string_literal: true

# Processes a deposit, namely shipping files to assembly NFS mount and starting the workflow
# If an error is raised, Sidekiq will retry up to a configured number of retries.
# Above that, it will exit and provide the error message in the background_job_result.
class UpdateJob < ApplicationJob
  queue_as :default
  attr_reader :background_job_result

  # Note that deciding when to stop retrying is handled below. Hence, not providing additional retry configuration
  # for Sidekiq.

  # @param [Hash] model_params
  # @param [Hash] filename, signed_ids for the blobs
  # @param [Hash] filename, globus_ids for the staged Globus files
  # @param [BackgroundJobResult] background_job_result
  # @param [Boolean] accession if true, closes the current version
  # @param [String] version_description
  # @param [String] user_versions ('none') - create, update, or do nothing with user versions on close.
  # rubocop:disable Metrics/AbcSize
  # rubocop:disable Metrics/MethodLength
  # rubocop:disable Metrics/ParameterLists
  def perform(model_params:,
              background_job_result:,
              signed_ids: {},
              globus_ids: {},
              version_description: nil,
              user_versions: 'none',
              accession: true)
    @background_job_result = background_job_result
    background_job_result_processing!

    model = Cocina::Models.build(model_params.with_indifferent_access)

    object_client = Dor::Services::Client.object(model.externalIdentifier)
    existing_version_status = object_client.version.status
    return unless check_versioning(model, existing_version_status.version)

    model = open_new_version_if_needed(model, version_description, existing_version_status, object_client)
    return if model.nil?

    # globus deposits may not have digests yet and they need to be generated before staging (copy)
    model = GlobusDigestGenerator.generate(cocina: model, globus_ids:)

    # not using a lock here since all model params are being provided rather than updating retrieved params.
    object_client.update(params: model, skip_lock: true)

    background_job_result.output = { druid: model.externalIdentifier }

    StageBlobs.stage(signed_ids, model.externalIdentifier)
    StageGlobus.stage(globus_ids, model.externalIdentifier)

    object_client.version.close(user_versions:) if accession

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
  # rubocop:enable Metrics/AbcSize
  # rubocop:enable Metrics/MethodLength
  # rubocop:enable Metrics/ParameterLists

  def check_versioning(model, existing_version)
    allowed_versions = [existing_version, existing_version + 1]
    return true if allowed_versions.include?(model.version)

    error_title = 'Version conflict'
    error_detail = "The repository is on version '#{existing_version}' and you " \
                   "tried to create/update version '#{model.version}'. " \
                   "Version is limited to #{allowed_versions.join(' or ')}."

    background_job_complete_with_error!(error_title, error_detail, model.externalIdentifier, existing_version,
                                        model.version)

    false
  end

  def open_new_version_if_needed(model, version_description, existing_version_status, object_client)
    return model if model.version == existing_version_status.version && existing_version_status.open?

    unless existing_version_status.openable?
      error_title = 'Version not openable'
      error_detail = "Attempted to open version #{model.version} but it cannot be opened."

      background_job_complete_with_error!(error_title, error_detail, model.externalIdentifier,
                                          existing_version_status.version, model.version)

      return
    end

    new_version_model = object_client.version.open(description: version_description || 'Update via sdr-api')

    Cocina::Models.without_metadata(model.new(version: new_version_model.version))
  end

  def background_job_result_processing!
    # Increment the try count
    background_job_result.try_count += 1
    background_job_result.processing!
  end

  def background_job_complete_with_error!(error_title, error_detail, druid, existing_version, provided_version)
    Honeybadger.notify("#{error_title}: #{error_detail}",
                       context: { external_identifier: druid,
                                  existing_version:,
                                  provided_version: })
    background_job_result.output = { errors: [title: error_title, detail: error_detail] }
    background_job_result.complete!
  end
end
