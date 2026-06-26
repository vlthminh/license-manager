# frozen_string_literal: true

class LicenseCheckinsController < ApplicationController
  def create
    result = Licenses::CheckinService.new(license_id: params[:license_id], user_id: params[:user_id]).call

    if result.success?
      render json: { message: result.message }, status: :ok
    else
      render json: { message: result.message }, status: error_status_for(result.message)
    end
  rescue ActiveRecord::RecordInvalid => e
    render json: { message: e.message }, status: :unprocessable_content
  rescue StandardError
    render json: { message: "An unexpected error occurred" }, status: :internal_server_error
  end

  private

  def error_status_for(message)
    message == "License not found" ? :not_found : :conflict
  end
end
