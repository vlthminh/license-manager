# frozen_string_literal: true

require "rails_helper"

# rubocop:disable RSpec/DescribeClass -- this exercises the interaction of two services, not a single class
RSpec.describe "License seat invariants" do
  it "keeps active_seats_count in sync with actual active checkouts after a random sequence of operations" do
    license = create(:license, max_seats: 5, active_seats_count: 0)
    user_ids = (1..10).to_a

    30.times do
      user_id = user_ids.sample

      if rand < 0.5
        Licenses::CheckoutService.new(license_id: license.id, user_id: user_id).call
      else
        Licenses::CheckinService.new(license_id: license.id, user_id: user_id).call
      end
    end

    license.reload
    actual_active_count = license.license_checkouts.active.count

    expect(license.active_seats_count).to eq(actual_active_count)
  end

  it "does not let active_seats_count go negative on a double checkin" do
    license = create(:license, max_seats: 2, active_seats_count: 1)
    create(:license_checkout, license: license, user_id: 1, status: :active)

    Licenses::CheckinService.new(license_id: license.id, user_id: 1).call
    second_result = Licenses::CheckinService.new(license_id: license.id, user_id: 1).call

    aggregate_failures do
      expect(second_result.success?).to be(false)
      expect(license.reload.active_seats_count).to eq(0)
    end
  end

  it "does not let active_seats_count exceed max_seats when checkouts race past capacity" do
    license = create(:license, max_seats: 1, active_seats_count: 0)

    Licenses::CheckoutService.new(license_id: license.id, user_id: 1).call
    second_result = Licenses::CheckoutService.new(license_id: license.id, user_id: 2).call

    aggregate_failures do
      expect(second_result.success?).to be(false)
      expect(license.reload.active_seats_count).to eq(1)
    end
  end
end
# rubocop:enable RSpec/DescribeClass
