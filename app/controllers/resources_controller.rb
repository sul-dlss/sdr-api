# frozen_string_literal: true

require 'base64'

class ResourcesController < ApplicationController
  before_action :authorize_request

  # POST /objects
  # rubocop:disable Metrics/AbcSize
  # rubocop:disable Metrics/MethodLength
  def create
    authorize! :resource
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
                            filesets: params[:structural].to_unsafe_h.fetch(:contains, []),
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
    file_sets(model_params[:structural].fetch(:contains, []))

    Cocina::Models::RequestDRO.new(model_params)
  end

  # Decorates the provided FileSets with the information we have in the ActiveStorage table.
  # externalIdentifier is also removed from the request.
  def file_sets(filesets)
    filesets.each do |fileset|
      fileset['version'] = 1
      fileset.dig('structural', 'contains').each do |file|
        blob = blob_for_signed_id(file.delete('externalIdentifier'))
        file['size'] = blob.byte_size
        file['hasMimeType'] = blob.content_type
        declared_md5 = file['hasMessageDigests'].find { |digest| digest.fetch('type') == 'md5' }.fetch('digest')
        calculated_md5 = base64_to_hexdigest(blob.checksum)
        raise "MD5 Mismatch for ActiveStorage::Blob<##{blob.id}>" if declared_md5 != calculated_md5

        file['version'] = 1
      end
    end
  end

  def blob_for_signed_id(signed_id)
    file_id = ActiveStorage.verifier.verified(signed_id, purpose: :blob_id)
    ActiveStorage::Blob.find(file_id)
  end

  def base64_to_hexdigest(base64)
    Base64.decode64(base64).unpack1('H*')
  end

  # JSON-API error response. See https://jsonapi.org/.
  def build_error(msg, err, code, _status)
    m = err.message.match(/:\s(\d{3})/)
    !m.nil? && m[1] != code ? code = m[1] : ''
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
      status: code
    }
  end

  def workflow_client
    Dor::Workflow::Client.new(url: Settings.workflow.url,
                              logger: Rails.logger,
                              timeout: 60)
  end
end
