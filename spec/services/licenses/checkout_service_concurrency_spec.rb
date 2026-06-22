# frozen_string_literal: true

require "rails_helper"

# This spec exercises real concurrent DB connections, so it cannot run inside
# the transactional-fixtures rollback used by the rest of the suite: other
# threads need to see the license row that this example creates. Data is
# cleaned up manually in the `after` hook instead of via transaction rollback.
RSpec.describe Licenses::CheckoutService do
  self.use_transactional_tests = false

  after do
    LicenseAuditLog.delete_all
    LicenseCheckout.delete_all
    License.delete_all
    Company.delete_all
  end

  describe "#call under concurrent load" do
    # rubocop:disable RSpec/ExampleLength -- thread setup/teardown for a concurrency test is inherently longer
    it "never allocates more seats than max_seats, even with many simultaneous requests" do
      max_seats = 5
      concurrent_requests = 20
      license = create(:license, max_seats: max_seats, active_seats_count: 0)

      results = Array.new(concurrent_requests)
      threads = Array.new(concurrent_requests) do |i|
        Thread.new do
          results[i] = described_class.new(license_id: license.id, user_id: i).call
        end
      end
      threads.each(&:join)

      successful_count = results.count(&:success?)

      aggregate_failures do
        expect(successful_count).to eq(max_seats)
        expect(license.reload.active_seats_count).to eq(max_seats)
        expect(license.license_checkouts.active.count).to eq(max_seats)
      end
    end
    # rubocop:enable RSpec/ExampleLength
  end
end
