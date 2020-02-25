# frozen_string_literal: true

class ResourcesController < ApplicationController
  before_action :authorize_request

  # POST /objects
  # rubocop:disable Metrics/AbcSize
  # rubocop:disable Metrics/MethodLength
  def create
    begin
      response_cocina_obj = Dor::Services::Client.objects.register(params: cocina_model)
    rescue Dor::Services::Client::UnexpectedResponse => e
      return render build_error('Error registering object with dor-services-app', e, '502', :bad_gateway)
    rescue Dor::Services::Client::ConnectionFailed => e
      return render build_error('Unable to reach dor-services-app', e, '504',
                                :gateway_timeout)
    end

    # Doing this here rather than IngestJob so that have accurate timestamp for milestone.
    begin
      workflow_client.create_workflow_by_name(response_cocina_obj.externalIdentifier, 'registrationWF', version: 1)
    rescue Dor::WorkflowException => e
      return render build_error('Error creating registrationWF with workflow-service', e, '502',
                                :bad_gateway)
    end

    result = BackgroundJobResult.create

    IngestJob.perform_later(druid: response_cocina_obj.externalIdentifier,
                            filesets: params[:structural].to_unsafe_h.fetch(:contains),
                            background_job_result: result)

    render json: { druid: response_cocina_obj.externalIdentifier },
           location: result,
           status: :created
  end
  # rubocop:enable Metrics/AbcSize
  # rubocop:enable Metrics/MethodLength

  private

  def cocina_model
    model_params = params.to_unsafe_h
    model_params[:label] = ':auto' if model_params[:label].nil?
    model_params[:version] = 1 if model_params[:version].nil?
    # Presently, the create model endpoint in dor-services-app, can't handle filesets,
    # so, we remove them here and make contentMetadata.xml instead.
    model_params[:structural].delete(:contains)
    Cocina::Models::RequestDRO.new(model_params)
  end

  # JSON-API error response. See https://jsonapi.org/
  def build_error(msg, err, code, status)
    {
      json: {
        errors: [
          {
            "status": code,
            "title": msg,
            "detail": err.message
          }
        ]
      },
      content_type: 'application/vnd.api+json',
      status: status
    }
  end

  def workflow_client
    Dor::Workflow::Client.new(url: Settings.workflow.url,
                              logger: Rails.logger,
                              timeout: 60)
  end
end
