# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Licenses", type: :request do
  describe "GET /companies/:company_id/licenses" do
    it "returns 200 with all licenses for the company" do
      company = create(:company)
      create_list(:license, 2, company: company)

      get "/companies/#{company.id}/licenses"

      aggregate_failures do
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["total_count"]).to eq(2)
        expect(response.parsed_body["licenses"].size).to eq(2)
      end
    end

    it "returns license fields including seat counts and license_key" do
      company = create(:company)
      license = create(:license, company: company, max_seats: 5, active_seats_count: 2, license_key: "KEY-001")

      get "/companies/#{company.id}/licenses"

      entry = response.parsed_body["licenses"].first
      aggregate_failures do
        expect(entry["id"]).to eq(license.id)
        expect(entry["name"]).to eq(license.name)
        expect(entry["max_seats"]).to eq(5)
        expect(entry["active_seats_count"]).to eq(2)
        expect(entry["license_key"]).to eq("KEY-001")
      end
    end

    it "only returns licenses belonging to the requested company" do
      company = create(:company)
      other_company = create(:company)
      create(:license, company: company)
      create(:license, company: other_company)

      get "/companies/#{company.id}/licenses"

      expect(response.parsed_body["total_count"]).to eq(1)
    end

    it "returns an empty list when the company has no licenses" do
      company = create(:company)

      get "/companies/#{company.id}/licenses"

      aggregate_failures do
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["licenses"]).to be_empty
        expect(response.parsed_body["total_count"]).to eq(0)
      end
    end

    it "paginates results" do
      company = create(:company)
      create_list(:license, 3, company: company)

      get "/companies/#{company.id}/licenses", params: { page: 1, per_page: 2 }

      aggregate_failures do
        expect(response.parsed_body["licenses"].size).to eq(2)
        expect(response.parsed_body["page"]).to eq(1)
        expect(response.parsed_body["per_page"]).to eq(2)
        expect(response.parsed_body["total_count"]).to eq(3)
      end
    end

    it "returns 404 when the company does not exist" do
      get "/companies/-1/licenses"

      expect(response).to have_http_status(:not_found)
    end

    it "returns 422 when ActiveRecord::RecordInvalid is raised" do
      company = create(:company)
      allow_any_instance_of(Company).to receive(:licenses).and_raise(ActiveRecord::RecordInvalid)

      get "/companies/#{company.id}/licenses"

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "returns 500 when an unexpected error is raised" do
      company = create(:company)
      allow_any_instance_of(Company).to receive(:licenses).and_raise(StandardError)

      get "/companies/#{company.id}/licenses"

      aggregate_failures do
        expect(response).to have_http_status(:internal_server_error)
        expect(response.parsed_body["message"]).to eq("An unexpected error occurred")
      end
    end
  end
end
