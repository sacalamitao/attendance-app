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

ActiveRecord::Schema[8.1].define(version: 2026_09_19_192720) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "attendances", force: :cascade do |t|
    t.bigint "attendee_id", null: false
    t.datetime "created_at", null: false
    t.bigint "event_id", null: false
    t.string "ministry_classification", null: false
    t.bigint "operator_id", null: false
    t.datetime "scanned_at", null: false
    t.datetime "updated_at", null: false
    t.index ["attendee_id"], name: "index_attendances_on_attendee_id"
    t.index ["event_id", "attendee_id"], name: "index_attendances_on_event_id_and_attendee_id", unique: true
    t.index ["event_id", "ministry_classification"], name: "index_attendances_on_event_id_and_ministry_classification"
    t.index ["event_id", "scanned_at"], name: "index_attendances_on_event_id_and_scanned_at"
    t.index ["event_id"], name: "index_attendances_on_event_id"
    t.index ["operator_id"], name: "index_attendances_on_operator_id"
    t.check_constraint "ministry_classification::text = ANY (ARRAY['kkb'::character varying, 'yan'::character varying, 'mens'::character varying, 'womens'::character varying]::text[])", name: "attendances_ministry_classification_check"
  end

  create_table "attendees", force: :cascade do |t|
    t.date "birthdate", null: false
    t.datetime "created_at", null: false
    t.datetime "deactivated_at"
    t.string "full_name", null: false
    t.string "gender", null: false
    t.string "qr_token", null: false
    t.datetime "updated_at", null: false
    t.index ["birthdate"], name: "index_attendees_on_birthdate"
    t.index ["deactivated_at"], name: "index_attendees_on_deactivated_at"
    t.index ["full_name"], name: "index_attendees_on_full_name"
    t.index ["qr_token"], name: "index_attendees_on_qr_token", unique: true
    t.check_constraint "gender::text = ANY (ARRAY['male'::character varying, 'female'::character varying]::text[])", name: "attendees_gender_check"
  end

  create_table "events", force: :cascade do |t|
    t.datetime "closed_at"
    t.datetime "created_at", null: false
    t.time "end_time", null: false
    t.date "event_date", null: false
    t.string "location", null: false
    t.string "name", null: false
    t.datetime "opened_at"
    t.time "start_time", null: false
    t.string "status", default: "draft", null: false
    t.datetime "updated_at", null: false
    t.index ["event_date"], name: "index_events_on_event_date"
    t.index ["status"], name: "index_events_on_status"
    t.check_constraint "end_time >= start_time", name: "events_time_range_check"
    t.check_constraint "status::text = ANY (ARRAY['draft'::character varying, 'open'::character varying, 'closed'::character varying]::text[])", name: "events_status_check"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.integer "failed_attempts", default: 0, null: false
    t.datetime "locked_at"
    t.string "name", default: "", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.string "role", default: "operator", null: false
    t.string "unlock_token"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["unlock_token"], name: "index_users_on_unlock_token", unique: true
    t.check_constraint "role::text = ANY (ARRAY['admin'::character varying, 'operator'::character varying]::text[])", name: "users_role_check"
  end

  add_foreign_key "attendances", "attendees"
  add_foreign_key "attendances", "events"
  add_foreign_key "attendances", "users", column: "operator_id"
end
