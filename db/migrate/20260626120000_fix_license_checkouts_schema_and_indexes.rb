# frozen_string_literal: true

class FixLicenseCheckoutsSchemaAndIndexes < ActiveRecord::Migration[8.1]
  def change
    change_column_null :license_checkouts, :checked_out_at, false

    add_index :license_checkouts, %i[license_id checked_out_at],
              name: "idx_license_checkouts_on_license_id_and_checked_out_at"

    add_index :license_checkouts, %i[license_id status],
              name: "idx_license_checkouts_on_license_id_and_status"
  end
end
