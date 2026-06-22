# frozen_string_literal: true

module Licenses
  class CheckinService
    Result = Struct.new(:success?, :message, keyword_init: true)

    def initialize(license_id:, user_id:)
      @license_id = license_id
      @user_id = user_id
    end

    def call
      result = perform
      record_audit_log(result)
      result
    end

    private

    def perform
      license = License.find_by(id: @license_id)
      return Result.new(success?: false, message: "License not found") unless license

      license.with_lock do
        checkout = license.license_checkouts.find_by(user_id: @user_id, status: :active)
        next Result.new(success?: false, message: "No active checkout for this user") unless checkout

        checkout.update!(status: :returned, checked_in_at: Time.current)
        # rubocop:disable Rails/SkipsModelValidations -- atomic counter bump, validated by the DB CHECK constraint
        license.decrement!(:active_seats_count)
        # rubocop:enable Rails/SkipsModelValidations

        Result.new(success?: true, message: "License returned successfully")
      end
    end

    def record_audit_log(result)
      LicenseAuditLog.create!(
        license_id: @license_id,
        user_id: @user_id,
        action: :checkin,
        success: result.success?,
        message: result.message
      )
    end
  end
end
