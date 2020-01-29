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
    file_nodes = filesets.flat_map { |fs| fs.fetch('structural').fetch('contains') }
    file_names = copy_files_to_staging(dir, file_nodes)

    # generate contentMetadata.xml
    xml = ContentMetadataGenerator.generate(filesets: filesets, file_names: file_names, druid: druid)

    dir.write_file('contentMetadata.xml', xml)

    # Setting lane_id to low for all, which is appropriate for all current use cases. In the future, may want to make
    # this an API parameter.
    workflow_client.create_workflow_by_name(druid, 'assemblyWF', version: 1, lane_id: 'low')
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
  # @param [Array<Hash>] a list of hashes representing Cocina File objects
  # @return [Hash<String,String>] a map of filenames (from the metadata) to the full paths to the files that were copied
  def copy_files_to_staging(dir, file_nodes)
    files(file_nodes).each do |blob|
      dir.copy_file(ActiveStorage::Blob.service.path_for(blob.key), blob.filename.to_s)
    end
    file_nodes.each_with_object({}) do |file_node, out|
      filename = file_node.fetch('filename')
      out[filename] = File.join(dir.content_dir, filename)
    end
  end

  # @param [Array<Hash>] a list of hashes representing Cocina File objects
  # @return [Array<ActiveStorage::Blob>] Given a list of file_json, return the corresponding blob objects
  def files(file_nodes)
    signed_ids = file_nodes.map { |fs| fs.fetch('externalIdentifier') }

    file_ids = signed_ids.map { |signed_id| ActiveStorage.verifier.verified(signed_id, purpose: :blob_id) }

    # This can raise ActiveRecord::RecordNotFound if one or more of the files don't exist
    ActiveStorage::Blob.find(file_ids)
  end
end
