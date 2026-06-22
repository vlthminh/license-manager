# frozen_string_literal: true

require "rails_helper"

RSpec.describe LicenseAuditLog, type: :model do
  it "has a valid factory" do
    expect(build(:license_audit_log)).to be_valid
  end

  it "is invalid without a user_id" do
    expect(build(:license_audit_log, user_id: nil)).not_to be_valid
  end

  it "is invalid without a license_id" do
    expect(build(:license_audit_log, license_id: nil)).not_to be_valid
  end

  it "is invalid without a message" do
    expect(build(:license_audit_log, message: nil)).not_to be_valid
  end

  describe "action enum" do
    it "defines checkout and checkin actions" do
      expect(described_class.actions).to eq("checkout" => 0, "checkin" => 1)
    end
  end

  it "logs a record for a license id that does not exist (no DB-level FK)" do
    log = create(:license_audit_log, license_id: -1, success: false, message: "License not found")

    expect(log).to be_persisted
  end
end
