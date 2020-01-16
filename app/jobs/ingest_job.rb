# frozen_string_literal: true

# Processes a deposit, namely creating contentMetadata, shipping files and starting the workflow
class IngestJob < ApplicationJob
  queue_as :default

  # @param [String] druid
  # @param [Array<Hash>] filesets the data for creating the structure
  # @param [BackgroundJobResult] background_job_result
  def perform(druid:, filesets:, background_job_result:)
    background_job_result.processing!

    dir = StagingDirectory.new(druid: druid, staging_location: Settings.staging_location)

    file_names = copy_files_to_staging(dir, filesets)

    # generate contentMetadata.xml
    xml = ContentMetadataGenerator.generate(file_names: file_names, druid: druid)
    dir.write_file('contentMetadata.xml', xml)

    workflow_client.create_workflow_by_name(druid, 'assemblyWF', version: 1)
  ensure
    background_job_result.complete!
  end

  private

  def workflow_client
    Dor::Workflow::Client.new(url: Settings.workflow.url,
                              logger: Rails.logger,
                              timeout: 60)
  end

  # Copy files to the staging directory from ActiveStorage for the assembly workflow
  # @return [Array<String>] a list of full paths to the files that were copied
  def copy_files_to_staging(dir, filesets)
    files(filesets).each do |blob|
      dir.copy_file(ActiveStorage::Blob.service.path_for(blob.key), blob.filename.to_s)
    end
    filesets.map { |fs| File.join(dir.content_dir, fs['label']) }
  end

  # @return [Array<ActiveStorage::Blob>] Given a list of filesets, return the corresponding blob objects
  def files(filesets)
    signed_ids = filesets.map { |fs| fs.fetch('structural').fetch('hasMember').first }

    file_ids = signed_ids.map { |signed_id| ActiveStorage.verifier.verified(signed_id, purpose: :blob_id) }

    # This can raise ActiveRecord::RecordNotFound if one or more of the files don't exist
    ActiveStorage::Blob.find(file_ids)
  end
end
