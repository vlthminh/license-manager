# frozen_string_literal: true

class LicenseAuditLog < ApplicationRecord
  enum :action, { checkout: 0, checkin: 1 }

  validates :user_id, presence: true
  validates :license_id, presence: true
  validates :message, presence: true
end
