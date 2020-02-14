# frozen_string_literal: true

class ResourcesController < ApplicationController
  before_action :authorize_request

  # POST /objects
  def create
    begin
      response_cocina_obj = Dor::Services::Client.objects.register(params: cocina_model)
    rescue Dor::Services::Client::UnexpectedResponse => e
      return render build_error('Bad Request', e, '400', :bad_request)
    rescue Dor::Services::Client::ConnectionFailed => e
      return render build_error('Unable to reach dor-services-app', e, '504', :gateway_timeout)
    end

    result = BackgroundJobResult.create

    IngestJob.perform_later(druid: response_cocina_obj.externalIdentifier,
                            filesets: params[:structural].to_unsafe_h.fetch(:contains),
                            background_job_result: result)

    render json: { druid: response_cocina_obj.externalIdentifier },
           location: result,
           status: :created
  end

  private

  def cocina_model
    model_params = params.to_unsafe_h
    model_params[:label] = ':auto' if model_params[:label].nil?
    model_params[:version] = 1 if model_params[:version].nil?
    model_params[:structural].delete(:contains)
    clean_embargo_release_date(model_params)
    clean_catkey(model_params)
    Cocina::Models::RequestDRO.new(model_params)
  end

  def clean_embargo_release_date(model_params)
    embargo_release_date = model_params[:access].delete(:embargoReleaseDate)
    return if embargo_release_date.nil?

    model_params[:access][:embargo] = {
      releaseDate: embargo_release_date,
      access: 'world'
    }
  end

  def clean_catkey(model_params)
    catkey = model_params[:identification].delete(:catkey)
    return if catkey.nil?

    model_params[:identification][:catalogLinks] = [{
      catalog: 'symphony',
      catalogRecordId: catkey
    }]
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
