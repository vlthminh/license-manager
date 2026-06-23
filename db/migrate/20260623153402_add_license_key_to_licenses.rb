# frozen_string_literal: true

class AddLicenseKeyToLicenses < ActiveRecord::Migration[8.1]
  def change
    add_column :licenses, :license_key, :string

    # No NOT NULL yet — nothing generates a value on create at this point,
    # this is just the column + the uniqueness guarantee. Postgres allows
    # multiple NULLs under a unique index, so existing/future rows without
    # a key don't violate it.
    add_index :licenses, :license_key, unique: true
  end
end
