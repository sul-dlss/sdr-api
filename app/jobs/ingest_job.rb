# frozen_string_literal: true

# Processes a deposit, namely creating contentMetadata, shipping files and starting the workflow
class IngestJob < ApplicationJob
  queue_as :default

  def perform(druid:, background_job_result:)
    background_job_result.processing!

    # TODO: generate contentMetadata.xml
    # TODO: ship files
    workflow_client.create_workflow_by_name(druid, 'accessionWF')
  ensure
    background_job_result.complete!
  end

  private

  def workflow_client
    Dor::Workflow::Client.new(url: Settings.workflow.url,
                              logger: Rails.logger,
                              timeout: 60)
  end
end
