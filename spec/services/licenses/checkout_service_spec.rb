# frozen_string_literal: true

require "rails_helper"

RSpec.describe Licenses::CheckoutService do
  describe "#call" do
    context "when the license has available seats" do
      it "creates an active checkout and increments active_seats_count" do
        license = create(:license, max_seats: 2, active_seats_count: 0)

        result = described_class.new(license_id: license.id, user_id: 1).call

        aggregate_failures do
          expect(result.success?).to be(true)
          expect(result.message).to eq("License allocated successfully")
          expect(result.checkout).to be_persisted
          expect(result.checkout.status).to eq("active")
          expect(license.reload.active_seats_count).to eq(1)
        end
      end
    end

    context "when the license has no available seats" do
      it "rejects the checkout without creating a record" do
        license = create(:license, max_seats: 1, active_seats_count: 1)

        result = described_class.new(license_id: license.id, user_id: 1).call

        aggregate_failures do
          expect(result.success?).to be(false)
          expect(result.message).to eq("No available license seats left")
          expect(license.license_checkouts.count).to eq(0)
        end
      end
    end

    context "when the user already has an active checkout for the license" do
      it "rejects the checkout and does not double allocate" do
        license = create(:license, max_seats: 5, active_seats_count: 1)
        create(:license_checkout, license: license, user_id: 1, status: :active)

        result = described_class.new(license_id: license.id, user_id: 1).call

        aggregate_failures do
          expect(result.success?).to be(false)
          expect(result.message).to eq("User already has an active session")
          expect(license.reload.active_seats_count).to eq(1)
        end
      end
    end

    context "when the license does not exist" do
      it "rejects the checkout" do
        result = described_class.new(license_id: -1, user_id: 1).call

        aggregate_failures do
          expect(result.success?).to be(false)
          expect(result.message).to eq("License not found")
        end
      end
    end

    describe "audit logging" do
      it "records a successful checkout attempt" do
        license = create(:license, max_seats: 2, active_seats_count: 0)

        described_class.new(license_id: license.id, user_id: 1).call
        log = LicenseAuditLog.last

        aggregate_failures do
          expect(log.license_id).to eq(license.id)
          expect(log.user_id).to eq(1)
          expect(log.action).to eq("checkout")
          expect(log.success).to be(true)
          expect(log.message).to eq("License allocated successfully")
        end
      end

      it "records a rejected attempt even when the license does not exist" do
        described_class.new(license_id: -1, user_id: 1).call
        log = LicenseAuditLog.last

        aggregate_failures do
          expect(LicenseAuditLog.count).to eq(1)
          expect(log.license_id).to eq(-1)
          expect(log.success).to be(false)
          expect(log.message).to eq("License not found")
        end
      end
    end
  end
end
