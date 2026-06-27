# frozen_string_literal: true

class LicensesController < ApplicationController
  DEFAULT_PER_PAGE = 20
  MAX_PER_PAGE = 100

  def index
    company = Company.find_by(id: params[:company_id])
    return render json: { message: "Company not found" }, status: :not_found unless company

    paginated = company.licenses.page(params[:page]).per(per_page_param)

    render json: {
      licenses: paginated.map { |license| license_json(license) },
      page: paginated.current_page,
      per_page: paginated.limit_value,
      total_count: paginated.total_count
    }, status: :ok
  end

  private

  def per_page_param
    requested = params[:per_page].to_i
    requested = DEFAULT_PER_PAGE if requested <= 0
    requested.clamp(1, MAX_PER_PAGE)
  end

  def license_json(license)
    {
      id: license.id,
      name: license.name,
      max_seats: license.max_seats,
      active_seats_count: license.active_seats_count,
      license_key: license.license_key
    }
  end
end
