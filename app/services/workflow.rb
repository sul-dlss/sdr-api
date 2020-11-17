# frozen_string_literal: true

# Methods for interfacing with the workflow service
class Workflow
  def self.create_unless_exists(druid, workflow_name, version: 1)
    return unless workflow_client.workflow(pid: druid, workflow_name: workflow_name).empty?

    # Setting lane_id to low for all, which is appropriate for all current use cases. In the future, may want to make
    # this an API parameter.
    workflow_client.create_workflow_by_name(druid, workflow_name, version: version, lane_id: 'low')
  end

  def self.workflow_client
    Dor::Workflow::Client.new(url: Settings.workflow.url,
                              logger: Rails.logger,
                              timeout: 60)
  end
end
