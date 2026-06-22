# frozen_string_literal: true

# db/seeds.rb
#
# Demo data for the live interview walkthrough. Safe to re-run as many
# times as you want while rehearsing — it wipes only these demo records
# and resets IDs back to a known state every time, so the hardcoded
# license id in the demo script (license id = 1) always stays valid.
#
# Usage: bin/rails db:seed

puts "Seeding demo data..."

# --- Clean slate (children first, to respect FKs) -------------------
LicenseCheckout.delete_all
License.delete_all
Company.delete_all

# Reset PK sequences so re-running this always gives the same IDs.
# Without this, re-seeding mid-rehearsal would bump license ids up
# (2, 3, 4...) and break the hardcoded id in your demo commands.
%w[license_checkouts licenses companies].each do |table|
  ActiveRecord::Base.connection.reset_pk_sequence!(table)
end

# --- Company ----------------------------------------------------------
company = Company.create!(name: "ARMADA")

# --- Main demo license: starts EMPTY, max_seats: 2 ---------------------
# This is the one your demo script calls directly:
#   http POST :3000/licenses/1/checkouts user_id=1
#   http POST :3000/licenses/1/checkouts user_id=2
#   http POST :3000/licenses/1/checkouts user_id=3   # <- rejected, pool full
demo_license = License.create!(
  company: company,
  name: "Toon Boom Harmony 21 — Floating License",
  max_seats: 2,
  active_seats_count: 0
)

# --- Secondary license: already near capacity --------------------------
# Useful if you want to drop into `rails console` and show the
# active_seats_count invariant holding, without more live HTTP calls.
busy_license = License.create!(
  company: company,
  name: "Adobe Premiere Pro — Floating License",
  max_seats: 5,
  active_seats_count: 0
)

[201, 202, 203, 204].each do |user_id|
  result = Licenses::CheckoutService.new(license_id: busy_license.id, user_id: user_id).call
  raise "Seed checkout failed: #{result.message}" unless result.success?
end

# --- Summary ------------------------------------------------------------
busy_license.reload
puts "Done."
puts "  Company:      #{company.name} (id=#{company.id})"
puts "  demo_license: id=#{demo_license.id} \"#{demo_license.name}\" — " \
     "#{demo_license.active_seats_count}/#{demo_license.max_seats} seats used"
puts "  busy_license: id=#{busy_license.id} \"#{busy_license.name}\" — " \
     "#{busy_license.active_seats_count}/#{busy_license.max_seats} seats used"
