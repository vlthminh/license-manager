# frozen_string_literal: true

class License < ApplicationRecord
  belongs_to :company
  has_many :license_checkouts, dependent: :destroy

  validates :name, presence: true
  validates :max_seats, numericality: { only_integer: true, greater_than: 0 }
  validates :license_key, uniqueness: true, allow_nil: true
end
