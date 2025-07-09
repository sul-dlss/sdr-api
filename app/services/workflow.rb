# frozen_string_literal: true

# Methods for interfacing with the workflow service
class Workflow
  # @param [String] druid
  # @param [String] workflow_name
  # @param [Integer] version (1)
  # @param [String] priority ('default') determines the relative priority used for the workflow.
  #                                      Value may be 'low' or 'default'
  def self.create_unless_exists(druid, workflow_name, version: 1, priority: 'default')
    workflow_client = Dor::Services::Client.object(druid).workflow(workflow_name)
    return unless workflow_client.find.empty?

    workflow_client.create(version:, context: { priority: })
  end
end
