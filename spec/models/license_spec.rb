# frozen_string_literal: true

require "rails_helper"

RSpec.describe License, type: :model do
  it "has a valid factory" do
    expect(build(:license)).to be_valid
  end

  it "is invalid without a name" do
    license = build(:license, name: nil)

    expect(license).not_to be_valid
  end

  it "is invalid without a positive max_seats" do
    license = build(:license, max_seats: 0)

    expect(license).not_to be_valid
  end

  it "is valid without a license_key (no generation mechanism yet)" do
    expect(build(:license, license_key: nil)).to be_valid
  end

  it "is invalid with a license_key that's already taken" do
    create(:license, license_key: "DUPLICATE-KEY")
    license = build(:license, license_key: "DUPLICATE-KEY")

    expect(license).not_to be_valid
  end

  describe "associations" do
    it "has many license_checkouts and destroys them when the license is destroyed" do
      reflection = described_class.reflect_on_association(:license_checkouts)

      aggregate_failures do
        expect(reflection.macro).to eq(:has_many)
        expect(reflection.options[:dependent]).to eq(:destroy)
      end
    end
  end

  describe "database constraints" do
    let(:license) { create(:license, max_seats: 3, active_seats_count: 0) }

    # rubocop:disable Rails/SkipsModelValidations -- intentionally bypassing
    # validations to prove the DB-level CHECK constraint itself rejects bad data.
    it "rejects an active_seats_count above max_seats at the database level" do
      expect do
        license.update_column(:active_seats_count, 4)
      end.to raise_error(ActiveRecord::StatementInvalid, /active_seats_within_bounds/)
    end

    it "rejects a negative active_seats_count at the database level" do
      expect do
        license.update_column(:active_seats_count, -1)
      end.to raise_error(ActiveRecord::StatementInvalid, /active_seats_within_bounds/)
    end

    it "rejects a duplicate license_key at the database level" do
      create(:license, license_key: "DUPLICATE-KEY")
      other = create(:license, license_key: nil)

      expect do
        other.update_column(:license_key, "DUPLICATE-KEY")
      end.to raise_error(ActiveRecord::StatementInvalid, /index_licenses_on_license_key/)
    end
    # rubocop:enable Rails/SkipsModelValidations
  end
end
