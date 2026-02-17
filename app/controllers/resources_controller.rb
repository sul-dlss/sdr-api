# frozen_string_literal: true

require 'base64'

# rubocop:disable Metrics/ClassLength
class ResourcesController < ApplicationController
  class BlobError < StandardError; end
  class GlobusNotFoundError < StandardError; end

  before_action :authorize_request
  before_action :validate_version
  before_action :validate_from_openapi

  GLOBUS_PREFIX = 'globus://'
  CREATE_PARAMS_EXCLUDE_FROM_COCINA = %i[action controller resource accession priority assign_doi user_versions].freeze
  ID_NAMESPACE = 'https://cocina.sul.stanford.edu'

  # GET /resource/:id
  def show
    cocina_obj = Cocina::Models.without_metadata(Dor::Services::Client.object(params[:id]).find)
    authorize! cocina_obj, with: ResourcePolicy
    render json: cocina_obj
  rescue Dor::Services::Client::NotFoundResponse => e
    render build_error('404', e, "Object not found: #{params[:id]}")
  rescue Dor::Services::Client::UnexpectedResponse => e
    render build_error('500', e, 'Internal server error')
  end

  # POST /resource
  # rubocop:disable Metrics/MethodLength
  # rubocop:disable Metrics/AbcSize
  def create
    begin
      request_dro = cocina_request_model
    rescue BlobError => e
      # Returning 500 because not clear whose fault it is.
      return render build_error('500', e, 'Error matching uploading files to file parameters.')
    end
    authorize! request_dro, with: ResourcePolicy

    result = BackgroundJobResult.create(output: {})
    IngestJob.perform_later(model_params: JSON.parse(request_dro.to_json), # Needs to be sidekiq friendly serialization
                            signed_ids:,
                            globus_ids:,
                            background_job_result: result,
                            accession: params.fetch(:accession, false),
                            assign_doi: params.fetch(:assign_doi, false),
                            priority: params.fetch(:priority, 'default'),
                            user_versions: params.fetch(:user_versions, 'none'))

    render json: { jobId: result.id },
           location: result,
           status: :created
  end
  # rubocop:enable Metrics/MethodLength
  # rubocop:enable Metrics/AbcSize

  # PUT /resource/:id
  # This just proxies the response from DOR services app
  # rubocop:disable Metrics/MethodLength
  # rubocop:disable Metrics/AbcSize
  def update
    begin
      cocina_dro = cocina_update_model
    rescue BlobError => e
      # Returning 500 because not clear whose fault it is.
      return render build_error('500', e, 'Error matching uploading files to file parameters.')
    end

    authorize! cocina_dro, with: ResourcePolicy

    result = BackgroundJobResult.create(output: {})
    UpdateJob.perform_later(model_params: JSON.parse(cocina_dro.to_json), # Needs to be sidekiq friendly serialization
                            signed_ids:,
                            globus_ids:,
                            version_description: params[:versionDescription],
                            user_versions: params.fetch(:user_versions, 'none'),
                            background_job_result: result,
                            accession: params.fetch(:accession, false))

    render json: { jobId: result.id },
           location: result,
           status: :accepted
  end
  # rubocop:enable Metrics/MethodLength
  # rubocop:enable Metrics/AbcSize

  private

  def cocina_create_params
    params.except(*CREATE_PARAMS_EXCLUDE_FROM_COCINA).to_unsafe_h
  end

  def cocina_update_params
    params.except(:action, :controller, :resource, :id, :versionDescription, :user_versions, :accession).to_unsafe_h
  end

  def validate_version
    request_version = request.headers['X-Cocina-Models-Version']
    return if !request_version || CocinaVersionValidator.valid?(request_version)

    error = StandardError.new("The API accepts cocina-models version #{Cocina::Models::VERSION} " \
                              "but you provided #{request_version}.  " \
                              'Run "bundle update" and then retry your request.')
    render build_error('400', error, 'Cocina-models version mismatch')
  end

  def cocina_update_model
    new_model_params = cocina_update_params.deep_dup
    decorate_file_sets(new_model_params)
    Cocina::Models.build(new_model_params)
  end

  def cocina_request_model
    new_model_params = cocina_create_params.deep_dup
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
        next unless decoratable_file?(file[:externalIdentifier])

        decorate_file(file:,
                      version: model_params[:version],
                      external_id: file_identifier(model_params[:externalIdentifier],
                                                   choose_resource_id(fileset[:externalIdentifier])))
      end
    end
  end

  def valid_fileset_id?(external_id)
    external_id.start_with?("#{ID_NAMESPACE}/fileSet/")
  end

  def choose_resource_id(external_id)
    # take the uuid from a valid fileset ID or create a uuid
    valid_fileset_id?(external_id) ? get_fileset_uuid(external_id) : external_id
  end

  def file_identifier(object_id, resource_id)
    "#{ID_NAMESPACE}/file/#{object_id.delete_prefix('druid:')}-#{resource_id}/#{SecureRandom.uuid}"
  end

  def get_fileset_uuid(external_id)
    # get the uuid (012345) from a valid externalIdentifier such as https://cocina.sul.stanford.edu/fileSet/px880kw6696-012345
    external_id.split("#{ID_NAMESPACE}/fileSet/").second.split('-', 2).second
  end

  def metadata_for_blob(blob, file)
    file.delete(:externalIdentifier)
    file[:size] = blob.byte_size
    # Invalid JSON files uploaded for deposit with a JSON content type will trigger 400 errors in sdr-api since they are
    # parsed as JSON and rejected.  The work around is to change the content_type in the request for uploads like this
    # to something specific that will be changed back to application/json after upload is complete.
    # There is a corresponding translation in sdr-client.  See https://github.com/sul-dlss/happy-heron/issues/3075
    file[:hasMimeType] = if blob.content_type == 'application/x-stanford-json'
                           'application/json'
                         else
                           blob.content_type || 'application/octet-stream'
                         end
    declared_md5 = file[:hasMessageDigests].find { |digest| digest.fetch(:type) == 'md5' }.fetch(:digest)
    calculated_md5 = base64_to_hexdigest(blob.checksum)
    raise BlobError, "MD5 mismatch for #{file[:filename]}" if declared_md5 != calculated_md5
  end

  def metadata_for_file(globus_file, file)
    raise GlobusNotFoundError, "Globus file [#{globus_file}] not found." unless File.exist?(globus_file)

    file[:size] = File.size(globus_file)
    file[:hasMimeType] = Marcel::MimeType.for Pathname.new(globus_file)
    # file[:hasMessageDigests] are not calculated here since they could take
    # some time to generate when processing deposits with large files. Instead
    # digest generation happens in the asynchronous IngestJob or UpdateJob to
    # avoid a long HTTP response.
  end

  def decorate_blob(file)
    blob = blob_for_signed_id(file.delete(:externalIdentifier), file[:filename])
    metadata_for_blob(blob, file)
  end

  def decorate_globus(file)
    globus_file = file_from_globus(file.delete(:externalIdentifier))
    metadata_for_file(globus_file, file)
  end

  def decorate_file(file:, version:, external_id: nil)
    if signed_id?(file[:externalIdentifier])
      decorate_blob(file)
    elsif globus_id?(file[:externalIdentifier])
      external_id ||= file[:externalIdentifier]
      decorate_globus(file)
    end

    # Set file params post-processing for both ActiveStorage and Globus
    file[:externalIdentifier] = external_id if external_id
    file[:version] = version
  end

  # Decorates the provided FileSets with the information we have in the ActiveStorage table.
  # externalIdentifier is also removed from the request.
  def decorate_request_file_sets(model_params)
    file_sets(model_params).each do |fileset|
      fileset[:version] = 1
      fileset.dig(:structural, :contains).each do |file|
        decorate_file(file:, version: 1)
      end
    end
  end

  def blob_for_signed_id(signed_id, filename)
    file_id = ActiveStorage.verifier.verified(signed_id, purpose: :blob_id)
    ActiveStorage::Blob.find(file_id)
  rescue ActiveRecord::RecordNotFound
    raise BlobError, "Unable to find upload for #{filename} (#{signed_id})"
  end

  def file_from_globus(globus_id)
    globus_id.sub(GLOBUS_PREFIX, Settings.globus_location)
  end

  def file_sets(model_params)
    model_params.fetch(:structural, {}).fetch(:contains, [])
  end

  def signed_ids
    {}.tap do |signed_ids|
      file_sets(params).flat_map do |fileset|
        fileset.dig(:structural, :contains).filter_map do |file|
          # Only include ActiveStorage signed IDs
          signed_ids[file[:filename]] = file[:externalIdentifier] if signed_id?(file[:externalIdentifier])
        end
      end
    end
  end

  def globus_ids
    {}.tap do |globus_ids|
      file_sets(params).flat_map do |fileset|
        fileset.dig(:structural, :contains).filter_map do |file|
          # Only include Globus file IDs
          globus_ids[file[:filename]] = file[:externalIdentifier] if globus_id?(file[:externalIdentifier])
        end
      end
    end
  end

  # NOTE: sdr-api receives requests from both:
  #
  #   1. systems like H2 that rely on the API to deposit files to SDR; and
  #   2. users hand-creating objects via the sdr-client CLI.
  #
  # The latter use case allows a user to update an existing SDR object, e.g., to
  # amend an item's APO. This operation does not require sdr-api to handle files
  # and is merely passing through Cocina to SDR. One way we can tell whether a Cocina
  # structure depends on sdr-api to manage files is by sniffing files' external
  # identifiers. If the external identifier of a file is a legitimate signed id,
  # the originating user or system expects the API to manage files for them. On the
  # other hand, it can be assumed that SDR already has a file on hand for the object,
  # and sdr-api can simply pass through the structure undecorated.
  def signed_id?(file_id)
    ActiveStorage.verifier.valid_message?(file_id)
  end

  def globus_id?(file_id)
    file_id.start_with?(GLOBUS_PREFIX)
  end

  def decoratable_file?(file_id)
    signed_id?(file_id) || globus_id?(file_id)
  end

  def base64_to_hexdigest(base64)
    Base64.decode64(base64).unpack1('H*')
  end

  # JSON-API error response. See https://jsonapi.org/.
  # rubocop:disable Metrics/MethodLength
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
  # rubocop:enable Metrics/MethodLength
end
# rubocop:enable Metrics/ClassLength
