# frozen_string_literal: true

class CreateLicenses < ActiveRecord::Migration[8.1]
  def change
    create_table :licenses do |t|
      t.references :company, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :max_seats, null: false
      t.integer :active_seats_count, null: false, default: 0

      t.timestamps
    end

    add_check_constraint :licenses,
                         "active_seats_count >= 0 AND active_seats_count <= max_seats",
                         name: "active_seats_within_bounds"
  end
end
