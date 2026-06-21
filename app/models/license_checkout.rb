# frozen_string_literal: true

class LicenseCheckout < ApplicationRecord
  belongs_to :license

  enum :status, { active: 0, returned: 1 }

  validates :user_id, presence: true
end
