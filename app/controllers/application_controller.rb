# frozen_string_literal: true

class ApplicationController < ActionController::API
  rescue_from StandardError do |_e|
    render json: { message: "An unexpected error occurred" }, status: :internal_server_error
  end

  rescue_from ActiveRecord::RecordInvalid do |e|
    render json: { message: e.message }, status: :unprocessable_content
  end
end
