# frozen_string_literal: true

class CreateLicenseAuditLogs < ActiveRecord::Migration[8.1]
  def change
    # No foreign key on license_id: a "license not found" attempt must
    # still be logged, and that id never corresponds to a real row.
    create_table :license_audit_logs do |t|
      t.integer :license_id, null: false
      t.integer :user_id, null: false
      t.integer :action, null: false
      t.boolean :success, null: false, default: false
      t.string :message, null: false

      # created_at only — this table is append-only, records are never
      # updated, so updated_at would always be a meaningless duplicate.
      t.datetime :created_at, null: false
    end

    add_index :license_audit_logs, :license_id
    add_index :license_audit_logs, %i[user_id created_at]
  end
end
