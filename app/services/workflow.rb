# frozen_string_literal: true

# Methods for interfacing with the workflow service
class Workflow
  # Create a workflow unless it already exists for any version.
  # @param [String] druid
  # @param [String] workflow_name
  # @param [Integer] version (1)
  # @param [String] priority ('default') determines the relative priority used for the workflow.
  #                                      Value may be 'low' or 'default'
  def self.create_unless_exists(druid, workflow_name, version: 1, priority: 'default')
    return if exists?(druid, workflow_name)

    Dor::Services::Client.object(druid).workflow(workflow_name).create(version:, lane_id: priority)
  end

  def self.exists?(druid, workflow_name)
    Dor::Services::Client.object(druid).workflow(workflow_name).find.present?
  end
  private_class_method :exists?
end
