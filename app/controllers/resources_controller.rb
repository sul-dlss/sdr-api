# frozen_string_literal: true

class ResourcesController < ApplicationController
  before_action :authorize_request

  # POST /objects
  def create
    register_params
    begin
      response = Dor::Services::Client.objects.register(params: register_params)
    rescue Dor::Services::Client::UnexpectedResponse => e
      return render build_error('Bad Request', e, '400', :bad_request)
    rescue Dor::Services::Client::ConnectionFailed => e
      return render build_error('Unable to reach dor-services-app', e, '504', :gateway_timeout)
    end

    result = BackgroundJobResult.create

    IngestJob.perform_later(druid: response[:pid],
                            filesets: params[:structural].to_unsafe_h.fetch(:hasMember),
                            background_job_result: result)

    render json: { druid: response[:pid] },
           location: result,
           status: :created
  end

  private

  # @return [Hash] the parameters used to register an object.
  def register_params
    reg_params = {
      object_type: 'item',
      admin_policy: params[:administrative][:hasAdminPolicy]
    }

    # ':auto' is a special value for the registration service.
    # see https://github.com/sul-dlss/dor-services-app/blob/master/app/services/registration_service.rb#L37
    reg_params[:label] = params[:label].presence || ':auto'
    col_catkey = params[:identification][:catkey]
    reg_params[:metadata_source] = col_catkey ? 'label' : 'symphony'
    reg_params[:other_id] = "symphony:#{col_catkey}" if col_catkey
    reg_params[:collection] = params[:structural][:isMemberOf]
    # TODO: content_type (tag Process:Content Type:Book (ltr) ) can come from a lookup using params[:type]
    # reg_param[:tags] = ['Process:Content Type:Book (ltr)']
    reg_params
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
end
