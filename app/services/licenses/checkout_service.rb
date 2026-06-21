# frozen_string_literal: true

module Licenses
  class CheckoutService
    Result = Struct.new(:success?, :message, :checkout, keyword_init: true)

    def initialize(license_id:, user_id:)
      @license_id = license_id
      @user_id = user_id
    end

    def call
      license = License.find_by(id: @license_id)
      return Result.new(success?: false, message: "License not found") unless license

      license.with_lock do
        next Result.new(success?: false, message: "User already has an active session") if active_checkout_for?(license)

        if license.active_seats_count >= license.max_seats
          next Result.new(success?: false, message: "No available license seats left")
        end

        checkout = license.license_checkouts.create!(
          user_id: @user_id, status: :active, checked_out_at: Time.current
        )
        # rubocop:disable Rails/SkipsModelValidations -- atomic counter bump, validated by the DB CHECK constraint
        license.increment!(:active_seats_count)
        # rubocop:enable Rails/SkipsModelValidations

        Result.new(success?: true, message: "License allocated successfully", checkout: checkout)
      end
    end

    private

    def active_checkout_for?(license)
      license.license_checkouts.exists?(user_id: @user_id, status: :active)
    end
  end
end
