# frozen_string_literal: true

require 'base64'

# rubocop:disable Metrics/ClassLength
class ResourcesController < ApplicationController
  class BlobError < StandardError; end

  before_action :authorize_request
  before_action :validate_version

  # POST /resource
  # rubocop:disable Metrics/AbcSize
  # rubocop:disable Metrics/MethodLength
  def create
    begin
      request_dro = cocina_request_model(params.except(:action, :controller, :resource, :accession,
                                                       :assign_doi).to_unsafe_h)
    rescue BlobError => e
      # Returning 500 because not clear whose fault it is.
      return render build_error('500', e, 'Error matching uploading files to file parameters.')
    end
    authorize! request_dro, with: ResourcePolicy

    result = BackgroundJobResult.create(output: {})
    IngestJob.perform_later(model_params: JSON.parse(request_dro.to_json), # Needs to be sidekiq friendly serialization
                            signed_ids: signed_ids(params),
                            background_job_result: result,
                            start_workflow: params.fetch(:accession, false),
                            assign_doi: params.fetch(:assign_doi, false))

    render json: { jobId: result.id },
           location: result,
           status: :created
  end
  # rubocop:enable Metrics/AbcSize
  # rubocop:enable Metrics/MethodLength

  # PUT /resource/:id
  def update
    begin
      request_dro = cocina_model(params.except(:action, :controller, :resource, :id).to_unsafe_h)
    rescue BlobError => e
      # Returning 500 because not clear whose fault it is.
      return render build_error('500', e, 'Error matching uploading files to file parameters.')
    end

    authorize! request_dro, with: ResourcePolicy

    result = BackgroundJobResult.create(output: {})
    UpdateJob.perform_later(model_params: JSON.parse(request_dro.to_json), # Needs to be sidekiq friendly serialization
                            signed_ids: signed_ids(params),
                            background_job_result: result)

    render json: { jobId: result.id },
           location: result,
           status: :accepted
  end

  # This just proxies the response from DOR services app
  def show
    cocina_obj = Dor::Services::Client.object(params[:id]).find
    authorize! cocina_obj, with: ResourcePolicy
    render json: cocina_obj
  end

  private

  def validate_version
    request_version = request.headers['X-Cocina-Models-Version']
    return if !request_version || request_version == Cocina::Models::VERSION

    error = StandardError.new("The API accepts cocina-models version #{Cocina::Models::VERSION} " \
      "but you provided #{request_version}.  Run \"bundle update\" and then retry your request.")
    render build_error('400', error, 'Cocina-models version mismatch')
  end

  def cocina_model(model_params)
    new_model_params = model_params.deep_dup
    decorate_file_sets(new_model_params)
    Cocina::Models.build(new_model_params)
  end

  def cocina_request_model(model_params)
    new_model_params = model_params.deep_dup
    new_model_params[:version] = 1
    decorate_request_file_sets(new_model_params)
    Cocina::Models.build_request(new_model_params)
  end

  # Decorates the provided FileSets with the information we have in the ActiveStorage table.
  # externalIdentifier is also removed from the request.
  def decorate_file_sets(model_params)
    file_sets(model_params).each do |fileset|
      fileset[:version] = model_params[:version]
      fileset.dig(:structural, :contains).each do |file|
        decorate_file(file: file,
                      external_id: "#{model_params[:externalIdentifier]}/#{file[:filename]}",
                      version: model_params[:version])
      end
    end
  end

  # rubocop:disable Metrics/AbcSize
  def decorate_file(file:, version:, external_id: nil)
    blob = blob_for_signed_id(file.delete(:externalIdentifier), file[:filename])
    file[:externalIdentifier] = external_id if external_id
    file[:version] = version
    file[:size] = blob.byte_size
    file[:hasMimeType] = blob.content_type || 'application/octet-stream'
    declared_md5 = file[:hasMessageDigests].find { |digest| digest.fetch(:type) == 'md5' }.fetch(:digest)
    calculated_md5 = base64_to_hexdigest(blob.checksum)
    raise BlobError, "MD5 mismatch for #{file[:filename]}" if declared_md5 != calculated_md5
  end
  # rubocop:enable Metrics/AbcSize

  # Decorates the provided FileSets with the information we have in the ActiveStorage table.
  # externalIdentifier is also removed from the request.
  def decorate_request_file_sets(model_params)
    file_sets(model_params).each do |fileset|
      fileset[:version] = 1
      fileset.dig(:structural, :contains).each do |file|
        decorate_file(file: file, version: 1)
      end
    end
  end

  def blob_for_signed_id(signed_id, filename)
    file_id = ActiveStorage.verifier.verified(signed_id, purpose: :blob_id)
    ActiveStorage::Blob.find(file_id)
  rescue ActiveRecord::RecordNotFound
    raise BlobError, "Unable to find upload for #{filename} (#{signed_id})"
  end

  def file_sets(model_params)
    model_params.fetch(:structural, {}).fetch(:contains, [])
  end

  def signed_ids(model_params)
    file_sets(model_params).flat_map do |fileset|
      fileset.dig(:structural, :contains).map do |file|
        file[:externalIdentifier]
      end
    end
  end

  def base64_to_hexdigest(base64)
    Base64.decode64(base64).unpack1('H*')
  end

  # JSON-API error response. See https://jsonapi.org/.
  def build_error(error_code, err, msg)
    {
      json: {
        errors: [
          {
            status: error_code,
            title: msg,
            detail: err.message
          }
        ]
      },
      content_type: 'application/vnd.api+json',
      status: error_code
    }
  end
end
# rubocop:enable Metrics/ClassLength
