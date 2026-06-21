# frozen_string_literal: true

require "rails_helper"

RSpec.describe Licenses::CheckinService do
  describe "#call" do
    context "when the user has an active checkout" do
      it "marks the checkout as returned and decrements active_seats_count" do
        license = create(:license, max_seats: 2, active_seats_count: 1)
        checkout = create(:license_checkout, license: license, user_id: 1, status: :active)

        result = described_class.new(license_id: license.id, user_id: 1).call

        aggregate_failures do
          expect(result.success?).to be(true)
          expect(result.message).to eq("License returned successfully")
          expect(checkout.reload.status).to eq("returned")
          expect(checkout.checked_in_at).not_to be_nil
          expect(license.reload.active_seats_count).to eq(0)
        end
      end
    end

    context "when the user has no active checkout for the license" do
      it "rejects the checkin" do
        license = create(:license, max_seats: 2, active_seats_count: 0)

        result = described_class.new(license_id: license.id, user_id: 1).call

        aggregate_failures do
          expect(result.success?).to be(false)
          expect(result.message).to eq("No active checkout for this user")
          expect(license.reload.active_seats_count).to eq(0)
        end
      end
    end

    context "when the license does not exist" do
      it "rejects the checkin" do
        result = described_class.new(license_id: -1, user_id: 1).call

        aggregate_failures do
          expect(result.success?).to be(false)
          expect(result.message).to eq("License not found")
        end
      end
    end
  end
end
