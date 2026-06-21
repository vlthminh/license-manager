# frozen_string_literal: true

require "rails_helper"

RSpec.describe Company, type: :model do
  it "has a valid factory" do
    expect(build(:company)).to be_valid
  end

  it "is invalid without a name" do
    company = build(:company, name: nil)

    expect(company).not_to be_valid
  end

  describe "associations" do
    it "has many licenses and destroys them when the company is destroyed" do
      reflection = described_class.reflect_on_association(:licenses)

      aggregate_failures do
        expect(reflection.macro).to eq(:has_many)
        expect(reflection.options[:dependent]).to eq(:destroy)
      end
    end
  end
end
