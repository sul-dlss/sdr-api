# frozen_string_literal: true

class ResourcesController < ApplicationController
  # before_action :authorize_request

  # POST /objects
  def create
    register_params
    response = Dor::Services::Client.objects.register(params: register_params)
    workflow_client.create_workflow_by_name(response[:pid], 'accessionWF')

    render json: { druid: response[:pid] }, status: :created
  rescue Dor::Services::Client::ConnectionFailed => e
    render build_error('Unable to reach dor-services-app', e)
  end

  private

  def workflow_client
    Dor::Workflow::Client.new(url: Settings.workflow.url,
                              logger: Rails.logger,
                              timeout: 60)
  end

  # @return [Hash] the parameters used to register an object.
  def register_params
    reg_params = {
      object_type: 'object',
      admin_policy: 'TODO: what policy?' # https://github.com/sul-dlss/repository-api/issues/29
    }

    # ':auto' is a special value for the registration service.
    # see https://github.com/sul-dlss/dor-services-app/blob/master/app/services/registration_service.rb#L37
    reg_params[:label] = params[:collection_title].presence || ':auto'
    reg_params[:rights] = if reg_params[:label] == ':auto'
                            params[:collection_rights_catkey]
                          else
                            params[:collection_rights]
                          end
    reg_params[:rights] &&= reg_params[:rights].downcase
    col_catkey = params[:collection_catkey] || ''
    reg_params[:metadata_source] = col_catkey.blank? ? 'label' : 'symphony'
    reg_params[:other_id] = "symphony:#{col_catkey}" if col_catkey.present?
    reg_params
  end

  # JSON-API error response. See https://jsonapi.org/
  def build_error(msg, err)
    {
      json: {
        errors: [
          {
            "status": '504',
            "title": msg,
            "detail": err.message
          }
        ]
      },
      content_type: 'application/vnd.api+json',
      status: :gateway_timeout
    }
  end
end
