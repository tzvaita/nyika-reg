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

ActiveRecord::Schema[8.1].define(version: 2026_08_26_144441) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_admin_comments", force: :cascade do |t|
    t.bigint "author_id"
    t.string "author_type"
    t.text "body"
    t.datetime "created_at", null: false
    t.string "namespace"
    t.bigint "resource_id"
    t.string "resource_type"
    t.datetime "updated_at", null: false
    t.index ["author_type", "author_id"], name: "index_active_admin_comments_on_author"
    t.index ["namespace"], name: "index_active_admin_comments_on_namespace"
    t.index ["resource_type", "resource_id"], name: "index_active_admin_comments_on_resource"
  end

  create_table "case_documents", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "document_type", null: false
    t.bigint "documentable_id", null: false
    t.string "documentable_type", null: false
    t.string "file_link"
    t.text "note"
    t.date "sighted_on"
    t.datetime "updated_at", null: false
    t.bigint "uploaded_by_id"
    t.integer "verification_status", default: 0, null: false
    t.datetime "verified_at"
    t.bigint "verified_by_id"
    t.index ["documentable_type", "documentable_id", "document_type"], name: "index_case_documents_on_documentable_and_type"
    t.index ["documentable_type", "documentable_id"], name: "index_case_documents_on_documentable"
    t.index ["uploaded_by_id"], name: "index_case_documents_on_uploaded_by_id"
    t.index ["verified_by_id"], name: "index_case_documents_on_verified_by_id"
  end

  create_table "consent_records", force: :cascade do |t|
    t.integer "channel", default: 0, null: false
    t.string "consent_version", null: false
    t.datetime "created_at", null: false
    t.date "granted_on", null: false
    t.bigint "person_id", null: false
    t.integer "purpose", null: false
    t.bigint "recorded_by_id"
    t.datetime "updated_at", null: false
    t.text "withdrawal_note"
    t.datetime "withdrawn_at"
    t.index ["person_id", "purpose"], name: "index_consent_records_on_person_id_and_purpose"
    t.index ["person_id"], name: "index_consent_records_on_person_id"
    t.index ["recorded_by_id"], name: "index_consent_records_on_recorded_by_id"
  end

  create_table "households", force: :cascade do |t|
    t.integer "capture_source", default: 0, null: false
    t.bigint "captured_by_id"
    t.datetime "created_at", null: false
    t.date "last_confirmed_on"
    t.text "location_description"
    t.string "name", null: false
    t.string "principal_contact"
    t.string "reference", null: false
    t.integer "status", default: 0, null: false
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.datetime "verified_at"
    t.bigint "verified_by_id"
    t.index ["captured_by_id"], name: "index_households_on_captured_by_id"
    t.index ["name", "location_description"], name: "index_households_on_name_and_location"
    t.index ["reference"], name: "index_households_on_reference", unique: true
    t.index ["status"], name: "index_households_on_status"
    t.index ["token"], name: "index_households_on_token", unique: true
    t.index ["verified_by_id"], name: "index_households_on_verified_by_id"
  end

  create_table "people", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.integer "age_band"
    t.string "contact_method"
    t.datetime "created_at", null: false
    t.bigint "household_id", null: false
    t.string "name", null: false
    t.integer "relationship", default: 0, null: false
    t.integer "residency_status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.integer "year_of_birth"
    t.index ["household_id", "active"], name: "index_people_on_household_id_and_active"
    t.index ["household_id"], name: "index_people_on_household_id"
  end

  create_table "programme_cases", force: :cascade do |t|
    t.bigint "beneficiary_id"
    t.datetime "created_at", null: false
    t.bigint "household_id", null: false
    t.bigint "opened_by_id"
    t.date "opened_on", null: false
    t.integer "outcome"
    t.text "outcome_note"
    t.datetime "outcome_recorded_at"
    t.integer "programme_type", null: false
    t.string "reference", null: false
    t.integer "status", default: 0, null: false
    t.datetime "submitted_at"
    t.bigint "submitted_by_id"
    t.datetime "updated_at", null: false
    t.index ["beneficiary_id"], name: "index_programme_cases_on_beneficiary_id"
    t.index ["household_id", "programme_type"], name: "index_programme_cases_on_household_id_and_programme_type"
    t.index ["household_id"], name: "index_programme_cases_on_household_id"
    t.index ["opened_by_id"], name: "index_programme_cases_on_opened_by_id"
    t.index ["reference"], name: "index_programme_cases_on_reference", unique: true
    t.index ["status"], name: "index_programme_cases_on_status"
    t.index ["submitted_by_id"], name: "index_programme_cases_on_submitted_by_id"
  end

  create_table "users", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "name", default: "", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.integer "role", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["role"], name: "index_users_on_role"
  end

  create_table "versions", force: :cascade do |t|
    t.datetime "created_at"
    t.string "event", null: false
    t.bigint "item_id", null: false
    t.string "item_type", null: false
    t.text "object"
    t.text "object_changes"
    t.text "reason"
    t.string "source_channel"
    t.string "whodunnit"
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id"
    t.index ["source_channel"], name: "index_versions_on_source_channel"
  end

  add_foreign_key "case_documents", "users", column: "uploaded_by_id"
  add_foreign_key "case_documents", "users", column: "verified_by_id"
  add_foreign_key "consent_records", "people"
  add_foreign_key "consent_records", "users", column: "recorded_by_id"
  add_foreign_key "households", "users", column: "captured_by_id"
  add_foreign_key "households", "users", column: "verified_by_id"
  add_foreign_key "people", "households"
  add_foreign_key "programme_cases", "households"
  add_foreign_key "programme_cases", "people", column: "beneficiary_id"
  add_foreign_key "programme_cases", "users", column: "opened_by_id"
  add_foreign_key "programme_cases", "users", column: "submitted_by_id"
end
