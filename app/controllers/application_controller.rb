# frozen_string_literal: true

class ApplicationController < ActionController::API
  include RequestAuthorization
end
