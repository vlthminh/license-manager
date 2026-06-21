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
  end
end
