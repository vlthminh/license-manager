# frozen_string_literal: true

class LicenseCheckoutsController < ApplicationController
  def create
    result = Licenses::CheckoutService.new(license_id: params[:license_id], user_id: params[:user_id]).call

    if result.success?
      render json: { message: result.message, checkout: checkout_json(result.checkout) }, status: :created
    else
      render json: { message: result.message }, status: error_status_for(result.message)
    end
  end

  private

  def checkout_json(checkout)
    {
      id: checkout.id,
      license_id: checkout.license_id,
      user_id: checkout.user_id,
      status: checkout.status,
      checked_out_at: checkout.checked_out_at
    }
  end

  def error_status_for(message)
    message == "License not found" ? :not_found : :conflict
  end
end
