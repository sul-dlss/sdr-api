# frozen_string_literal: true

class ApplicationController < ActionController::API
  include RequestAuthorization
  include ActionPolicy::Controller
  authorize :user, through: :current_user
end
