# frozen_string_literal: true

# This exists to add authorization to active_storage
class DiskController < ActiveStorage::DiskController
  include JSONSchemer::Rails::Controller

  before_action :params_from_openapi

  def params_from_openapi
    openapi_validator.validated_params
  end
end
