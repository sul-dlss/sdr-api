# frozen_string_literal: true

# Processes a deposit, namely shipping files to assembly NFS mount and starting the workflow
# If an error is raised, Sidekiq will retry up to a configured number of retries.
# Above that, it will exit and provide the error message in the background_job_result.
class IngestJob < ApplicationJob
  queue_as :default
  # Note that deciding when to stop retrying is handled below. Hence, not providing additional retry configuration
  # for Sidekiq.

  # @param [Hash] model_params
  # @param [Hash] filename, signed_ids for the blobs
  # @param [BackgroundJobResult] background_job_result
  # @param [Boolean] start_workflow if true, start accessionWF
  # @param [Boolean] assign_doi if true, adds DOI to Cocina obj
  # @param [String] priority ('default') determines the relative priority used for the workflow.
  #                                      Value may be 'low' or 'default'
  # rubocop:disable Metrics/AbcSize
  # rubocop:disable Metrics/MethodLength
  # rubocop:disable Metrics/ParameterLists
  def perform(model_params:, background_job_result:, signed_ids: {}, globus_ids: {},
              start_workflow: true, assign_doi: false, priority: 'default')
    # Increment the try count
    background_job_result.try_count += 1
    background_job_result.processing!
    model = Cocina::Models.build_request(model_params.with_indifferent_access)
    model = GlobusDigestGenerator.generate(cocina: model, globus_ids:)
    begin
      response_cocina_obj = Dor::Services::Client.objects.register(params: model, assign_doi:)
      druid = response_cocina_obj.externalIdentifier
    rescue Dor::Services::Client::ConflictResponse => e
      # Should not expect this on first try so return as error
      if background_job_result.try_count == 1
        background_job_result.output = { errors: [title: 'Object with source_id already exists.', message: e.message] }
        background_job_result.complete!
        return
      end
      # Get the druid from the error message
      druid = /\((druid:.{11})\)/.match(e.message)[1]
    rescue Dor::Services::Client::BadRequestError => e
      # report as error and do not retry
      background_job_result.output = { errors: [title: 'HTTP 400 (Bad Request) from dor-services-app',
                                                message: e.message] }
      background_job_result.complete!
      return
    end
    background_job_result.output = { druid: }

    # Create workflow destroys existing steps if called again, so need to check if already created.
    Workflow.create_unless_exists(druid, 'registrationWF', version: 1, priority:)

    StageBlobs.stage(signed_ids, druid)
    StageGlobus.stage(globus_ids, druid)

    Workflow.create_unless_exists(druid, 'accessionWF', version: 1, priority:) if start_workflow

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
end
