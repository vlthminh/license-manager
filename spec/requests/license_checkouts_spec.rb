# frozen_string_literal: true

require "rails_helper"

RSpec.describe "License checkouts", type: :request do
  describe "POST /licenses/:license_id/checkouts" do
    it "returns 201 and the checkout when a seat is available" do
      license = create(:license, max_seats: 2, active_seats_count: 0)

      post "/licenses/#{license.id}/checkouts", params: { user_id: 1 }

      aggregate_failures do
        expect(response).to have_http_status(:created)
        expect(response.parsed_body["message"]).to eq("License allocated successfully")
        expect(response.parsed_body["checkout"]["user_id"]).to eq(1)
      end
    end

    it "returns 409 when no seats are available" do
      license = create(:license, max_seats: 1, active_seats_count: 1)

      post "/licenses/#{license.id}/checkouts", params: { user_id: 1 }

      aggregate_failures do
        expect(response).to have_http_status(:conflict)
        expect(response.parsed_body["message"]).to eq("No available license seats left")
      end
    end

    it "returns 409 when the user already has an active checkout" do
      license = create(:license, max_seats: 5, active_seats_count: 1)
      create(:license_checkout, license: license, user_id: 1, status: :active)

      post "/licenses/#{license.id}/checkouts", params: { user_id: 1 }

      expect(response).to have_http_status(:conflict)
    end

    it "returns 404 when the license does not exist" do
      post "/licenses/-1/checkouts", params: { user_id: 1 }

      expect(response).to have_http_status(:not_found)
    end

    it "returns 422 when the service raises ActiveRecord::RecordInvalid" do
      license = create(:license)
      allow_any_instance_of(Licenses::CheckoutService).to receive(:call).and_raise(ActiveRecord::RecordInvalid)

      post "/licenses/#{license.id}/checkouts", params: { user_id: 1 }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "returns 500 when the service raises an unexpected error" do
      license = create(:license)
      allow_any_instance_of(Licenses::CheckoutService).to receive(:call).and_raise(StandardError)

      post "/licenses/#{license.id}/checkouts", params: { user_id: 1 }

      aggregate_failures do
        expect(response).to have_http_status(:internal_server_error)
        expect(response.parsed_body["message"]).to eq("An unexpected error occurred")
      end
    end
  end

  describe "GET /licenses/:license_id/checkouts" do
    it "lists checkouts for the license, most recent first" do
      license = create(:license, max_seats: 5, active_seats_count: 2)
      older = create(:license_checkout, license: license, user_id: 1, checked_out_at: 2.days.ago)
      newer = create(:license_checkout, license: license, user_id: 2, checked_out_at: 1.day.ago)

      get "/licenses/#{license.id}/checkouts"

      aggregate_failures do
        expect(response).to have_http_status(:ok)
        ids = response.parsed_body["checkouts"].pluck("id")
        expect(ids).to eq([newer.id, older.id])
        expect(response.parsed_body["total_count"]).to eq(2)
      end
    end

    it "filters by status" do
      license = create(:license, max_seats: 5, active_seats_count: 1)
      active = create(:license_checkout, license: license, user_id: 1, status: :active)
      create(:license_checkout, license: license, user_id: 2, status: :returned)

      get "/licenses/#{license.id}/checkouts", params: { status: "active" }

      ids = response.parsed_body["checkouts"].pluck("id")
      expect(ids).to eq([active.id])
    end

    it "returns 422 for an invalid status filter" do
      license = create(:license, max_seats: 5)

      get "/licenses/#{license.id}/checkouts", params: { status: "bogus" }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "paginates results" do
      license = create(:license, max_seats: 5, active_seats_count: 3)
      create_list(:license_checkout, 3, license: license)

      get "/licenses/#{license.id}/checkouts", params: { page: 1, per_page: 2 }

      aggregate_failures do
        expect(response.parsed_body["checkouts"].size).to eq(2)
        expect(response.parsed_body["page"]).to eq(1)
        expect(response.parsed_body["per_page"]).to eq(2)
        expect(response.parsed_body["total_count"]).to eq(3)
      end
    end

    it "returns 404 when the license does not exist" do
      get "/licenses/-1/checkouts"

      expect(response).to have_http_status(:not_found)
    end
  end
end
