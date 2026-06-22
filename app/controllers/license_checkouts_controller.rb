# frozen_string_literal: true

class LicenseCheckoutsController < ApplicationController
  DEFAULT_PER_PAGE = 20
  MAX_PER_PAGE = 100

  def index
    license = License.find_by(id: params[:license_id])
    return render json: { message: "License not found" }, status: :not_found unless license
    return render json: { message: "Invalid status filter" }, status: :unprocessable_content if invalid_status_filter?

    render json: paginated_response(checkouts_for(license)), status: :ok
  end

  def create
    result = Licenses::CheckoutService.new(license_id: params[:license_id], user_id: params[:user_id]).call

    if result.success?
      render json: { message: result.message, checkout: checkout_json(result.checkout) }, status: :created
    else
      render json: { message: result.message }, status: error_status_for(result.message)
    end
  end

  private

  def invalid_status_filter?
    params[:status].present? && !LicenseCheckout.statuses.key?(params[:status])
  end

  def checkouts_for(license)
    scope = license.license_checkouts.order(checked_out_at: :desc)
    params[:status].present? ? scope.where(status: params[:status]) : scope
  end

  def paginated_response(scope)
    paginated = scope.page(params[:page]).per(per_page_param)

    {
      checkouts: paginated.map { |checkout| checkout_json(checkout) },
      page: paginated.current_page,
      per_page: paginated.limit_value,
      total_count: paginated.total_count
    }
  end

  def per_page_param
    requested = params[:per_page].to_i
    requested = DEFAULT_PER_PAGE if requested <= 0
    requested.clamp(1, MAX_PER_PAGE)
  end

  def checkout_json(checkout)
    {
      id: checkout.id,
      license_id: checkout.license_id,
      user_id: checkout.user_id,
      status: checkout.status,
      checked_out_at: checkout.checked_out_at,
      checked_in_at: checkout.checked_in_at
    }
  end

  def error_status_for(message)
    message == "License not found" ? :not_found : :conflict
  end
end
