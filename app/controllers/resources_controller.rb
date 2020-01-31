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
                            filesets: params[:structural].to_unsafe_h.fetch(:contains),
                            background_job_result: result)

    render json: { druid: response[:pid] },
           location: result,
           status: :created
  end

  private

  # @return [Hash] the parameters used to register an object.
  def register_params
    {
      object_type: 'item',
      admin_policy: params[:administrative][:hasAdminPolicy],
      tag: AdministrativeTags.for(type: params[:type], user: current_user.email),
      # ':auto' is a special value for the registration service.
      # see https://github.com/sul-dlss/dor-services-app/blob/master/app/services/registration_service.rb#L37
      label: params[:label].presence || ':auto',
      collection: params[:structural][:isMemberOf],
      rights: 'default' # this ensures it picks up the rights from the APO
    }.merge(source_params)
  end

  def source_params
    col_catkey = params[:identification][:catkey]
    return { metadata_source: 'label' } unless col_catkey

    {
      metadata_source: 'symphony',
      other_id: "symphony:#{col_catkey}"
    }
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
