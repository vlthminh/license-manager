# frozen_string_literal: true

FactoryBot.define do
  factory :license_audit_log do
    license_id { 1 }
    sequence(:user_id)
    action { :checkout }
    success { true }
    message { "License allocated successfully" }
  end
end
