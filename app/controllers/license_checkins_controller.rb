# frozen_string_literal: true

class LicenseCheckinsController < ApplicationController
  def create
    result = Licenses::CheckinService.new(license_id: params[:license_id], user_id: params[:user_id]).call

    if result.success?
      render json: { message: result.message }, status: :ok
    else
      render json: { message: result.message }, status: error_status_for(result.message)
    end
  end

  private

  def error_status_for(message)
    message == "License not found" ? :not_found : :conflict
  end
end
