# frozen_string_literal: true

FactoryBot.define do
  factory :license do
    company
    name { "#{Faker::App.name} License" }
    max_seats { 5 }
    active_seats_count { 0 }
  end
end
