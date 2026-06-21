# frozen_string_literal: true

class CreateLicenseCheckouts < ActiveRecord::Migration[8.1]
  def change
    create_table :license_checkouts do |t|
      t.references :license, null: false, foreign_key: true
      t.integer :user_id, null: false
      t.integer :status, null: false, default: 0
      t.datetime :checked_out_at
      t.datetime :checked_in_at

      t.timestamps
    end

    add_index :license_checkouts, %i[license_id user_id], unique: true,
                                                          where: "status = 0",
                                                          name: "idx_one_active_checkout_per_user_per_license"
  end
end
