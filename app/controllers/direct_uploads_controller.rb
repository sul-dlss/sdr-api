# frozen_string_literal: true

# This exists to add authorization to active_storage
class DirectUploadsController < ActiveStorage::DirectUploadsController
  before_action :authorize_request
  include RequestAuthorization
end
