# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_06_26_120000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "companies", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
  end

  create_table "license_audit_logs", force: :cascade do |t|
    t.integer "action", null: false
    t.datetime "created_at", null: false
    t.integer "license_id", null: false
    t.string "message", null: false
    t.boolean "success", default: false, null: false
    t.integer "user_id", null: false
    t.index ["license_id"], name: "index_license_audit_logs_on_license_id"
    t.index ["user_id", "created_at"], name: "index_license_audit_logs_on_user_id_and_created_at"
  end

  create_table "license_checkouts", force: :cascade do |t|
    t.datetime "checked_in_at"
    t.datetime "checked_out_at", null: false
    t.datetime "created_at", null: false
    t.bigint "license_id", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["license_id", "checked_out_at"], name: "idx_license_checkouts_on_license_id_and_checked_out_at"
    t.index ["license_id", "status"], name: "idx_license_checkouts_on_license_id_and_status"
    t.index ["license_id", "user_id"], name: "idx_one_active_checkout_per_user_per_license", unique: true, where: "(status = 0)"
    t.index ["license_id"], name: "index_license_checkouts_on_license_id"
  end

  create_table "licenses", force: :cascade do |t|
    t.integer "active_seats_count", default: 0, null: false
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.string "license_key"
    t.integer "max_seats", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_licenses_on_company_id"
    t.index ["license_key"], name: "index_licenses_on_license_key", unique: true
    t.check_constraint "active_seats_count >= 0 AND active_seats_count <= max_seats", name: "active_seats_within_bounds"
  end

  add_foreign_key "license_checkouts", "licenses"
  add_foreign_key "licenses", "companies"
end
