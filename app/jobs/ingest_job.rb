# frozen_string_literal: true

# Processes a deposit, namely shipping files to assembly NFS mount and starting the workflow
# If an error is raised, Sidekiq will retry up to a configured number of retries.
# Above that, it will exit and provide the error message in the background_job_result.
class IngestJob < ApplicationJob
  queue_as :default
  sidekiq_options retry: Settings.sdr_api.ingest_retries

  # @param [Hash] model_params
  # @param [Array<String>] signed_ids for the blobs
  # @param [Boolean] start_workflow if true, start accessionWF
  # @param [BackgroundJobResult] background_job_result
  # rubocop:disable Metrics/AbcSize
  # rubocop:disable Metrics/MethodLength
  def perform(model_params:, signed_ids:, background_job_result:, start_workflow: true)
    # Increment the try count
    background_job_result.try_count += 1
    background_job_result.processing!

    begin
      response_cocina_obj = Dor::Services::Client.objects.register(params: Cocina::Models::RequestDRO.new(model_params))
      druid = response_cocina_obj.externalIdentifier
    rescue Dor::Services::Client::ConflictResponse => e
      # Should not expect this on first try so return as error
      if background_job_result.try_count == 1
        background_job_result.output = { errors: [title: 'Object with source_id already exists.', message: e.message] }
        background_job_result.complete!
        return
      end
      # Get the druid from the error message
      druid = /\((druid:.+)\)/.match(e.message)[1]
    end
    background_job_result.output = { druid: druid }

    # Create workflow destroys existing steps if called again, so need to check if already created.
    create_workflow_unless_exists(druid, 'registrationWF')

    blobs = blobs_for(signed_ids)
    copy_files_to_staging(druid, blobs)

    create_workflow_unless_exists(druid, 'accessionWF') if start_workflow
    delete_from_active_storage(blobs)

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

  private

  def workflow_client
    Dor::Workflow::Client.new(url: Settings.workflow.url,
                              logger: Rails.logger,
                              timeout: 60)
  end

  # Copy files to the staging directory from ActiveStorage for the assembly workflow
  def copy_files_to_staging(druid, blobs)
    dir = StagingDirectory.new(druid: druid, staging_location: Settings.staging_location)
    blobs.each do |blob|
      dir.copy_file(ActiveStorage::Blob.service.path_for(blob.key), blob.filename.to_s)
    end
  end

  # @param [Array<Hash>] signed_ids for blobs
  # @return [Array<ActiveStorage::Blob>] corresponding blob objects
  def blobs_for(signed_ids)
    file_ids = signed_ids.map { |signed_id| ActiveStorage.verifier.verified(signed_id, purpose: :blob_id) }

    # This can raise ActiveRecord::RecordNotFound if one or more of the files don't exist
    ActiveStorage::Blob.find(file_ids)
  end

  def delete_from_active_storage(blobs)
    # This is a purge_later so not worried about delete errors.
    blobs.each(&:purge_later)
  end

  def create_workflow_unless_exists(druid, workflow_name)
    return unless workflow_client.workflow(pid: druid, workflow_name: workflow_name).empty?

    # Setting lane_id to low for all, which is appropriate for all current use cases. In the future, may want to make
    # this an API parameter.
    workflow_client.create_workflow_by_name(druid, workflow_name, version: 1, lane_id: 'low')
  end
end
