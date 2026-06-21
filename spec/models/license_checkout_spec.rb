# frozen_string_literal: true

require "rails_helper"

RSpec.describe LicenseCheckout, type: :model do
  it "has a valid factory" do
    expect(build(:license_checkout)).to be_valid
  end

  it "is invalid without a user_id" do
    checkout = build(:license_checkout, user_id: nil)

    expect(checkout).not_to be_valid
  end

  describe "status enum" do
    it "defines active and returned states" do
      expect(described_class.statuses).to eq("active" => 0, "returned" => 1)
    end
  end

  describe "database constraints" do
    it "rejects a second active checkout for the same user and license" do
      license = create(:license, max_seats: 5)
      create(:license_checkout, license: license, user_id: 1, status: :active)

      expect do
        create(:license_checkout, license: license, user_id: 1, status: :active)
      end.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "allows a new active checkout once the previous one was returned" do
      license = create(:license, max_seats: 5)
      create(:license_checkout, license: license, user_id: 1, status: :returned)

      expect do
        create(:license_checkout, license: license, user_id: 1, status: :active)
      end.not_to raise_error
    end
  end
end
