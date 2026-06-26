# frozen_string_literal: true

require "rails_helper"

RSpec.describe "License checkins", type: :request do
  describe "POST /licenses/:license_id/checkins" do
    it "returns 200 when the user has an active checkout" do
      license = create(:license, max_seats: 2, active_seats_count: 1)
      create(:license_checkout, license: license, user_id: 1, status: :active)

      post "/licenses/#{license.id}/checkins", params: { user_id: 1 }

      aggregate_failures do
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["message"]).to eq("License returned successfully")
      end
    end

    it "returns 409 when the user has no active checkout" do
      license = create(:license, max_seats: 2, active_seats_count: 0)

      post "/licenses/#{license.id}/checkins", params: { user_id: 1 }

      aggregate_failures do
        expect(response).to have_http_status(:conflict)
        expect(response.parsed_body["message"]).to eq("No active checkout for this user")
      end
    end

    it "returns 404 when the license does not exist" do
      post "/licenses/-1/checkins", params: { user_id: 1 }

      expect(response).to have_http_status(:not_found)
    end

    it "returns 422 when the service raises ActiveRecord::RecordInvalid" do
      license = create(:license)
      allow_any_instance_of(Licenses::CheckinService).to receive(:call).and_raise(ActiveRecord::RecordInvalid)

      post "/licenses/#{license.id}/checkins", params: { user_id: 1 }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "returns 500 when the service raises an unexpected error" do
      license = create(:license)
      allow_any_instance_of(Licenses::CheckinService).to receive(:call).and_raise(StandardError)

      post "/licenses/#{license.id}/checkins", params: { user_id: 1 }

      aggregate_failures do
        expect(response).to have_http_status(:internal_server_error)
        expect(response.parsed_body["message"]).to eq("An unexpected error occurred")
      end
    end
  end
end
