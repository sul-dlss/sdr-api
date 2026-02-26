# frozen_string_literal: true

class ApplicationController < ActionController::API
  include RequestAuthorization
  include ActionPolicy::Controller
  include JSONSchemer::Rails::Controller

  authorize :user, through: :current_user

  rescue_from(ActionPolicy::Unauthorized) do |_exp|
    render json: { error: 'Not Authorized' }, status: :unauthorized
  end

  private

  # This overrides JSONSchemer::Rails::Controller to provide our ref_resolver
  def openapi_validator
    @openapi_validator ||= JSONSchemer::Rails::OpenApiValidator.new(request, ref_resolver:)
  end

  # Resolves the cocina-models copy of openapi.yml
  def ref_resolver
    @ref_resolver ||= proc { |url|
      raise "Unknown Reference #{url}" unless url.to_s.starts_with? 'https://raw.githubusercontent.com/sul-dlss/cocina-models'

      Cocina::Models::Validators::JsonSchemaValidator.document
    }
  end
end
