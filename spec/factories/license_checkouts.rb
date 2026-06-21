# frozen_string_literal: true

FactoryBot.define do
  factory :license_checkout do
    license
    sequence(:user_id)
    status { :active }
    checked_out_at { Time.current }
    checked_in_at { nil }
  end
end
