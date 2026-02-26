# frozen_string_literal: true

# This exists to add authorization to active_storage
class DirectUploadsController < ActiveStorage::DirectUploadsController
  include JSONSchemer::Rails::Controller
  include RequestAuthorization

  before_action :validate_from_openapi
  before_action :authorize_request
end
