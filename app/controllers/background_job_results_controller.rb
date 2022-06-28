# frozen_string_literal: true

# Controller for background job results
class BackgroundJobResultsController < ApplicationController
  before_action :authorize_request

  rescue_from ActiveRecord::RecordNotFound do |exception|
    render json: {
             errors: [
               { title: 'not found', detail: exception.message }
             ]
           }, status: :not_found
  end

  def show
    @result = BackgroundJobResult.find(params[:id])
    render status: @result.complete? ? :ok : :accepted
  end
end
