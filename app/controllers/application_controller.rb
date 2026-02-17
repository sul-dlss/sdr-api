# frozen_string_literal: true

class ApplicationController < ActionController::API
  include RequestAuthorization
  include ActionPolicy::Controller

  authorize :user, through: :current_user

  rescue_from(ActionPolicy::Unauthorized) do |_exp|
    render json: { error: 'Not Authorized' }, status: :unauthorized
  end

  def validate_from_openapi
    errors = openapi_validator.validate_body.to_a
    raise(Cocina::ValidationError, errors.pluck('error').join('; ')) if errors.any?
  end

  # cast any parameters that are not part of the OpenAPI specification
  def params_from_openapi
    openapi_validator.validated_params
  end

  private

  def openapi_validator
    @openapi_validator ||= OpenApiValidator.new(request)
  end
end
