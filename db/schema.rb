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

ActiveRecord::Schema[8.1].define(version: 2026_08_27_130429) do
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

  create_table "contributions", force: :cascade do |t|
    t.decimal "amount", precision: 12, scale: 2
    t.integer "contribution_kind", default: 0, null: false
    t.datetime "created_at", null: false
    t.text "exception_note"
    t.bigint "household_id", null: false
    t.string "item_description"
    t.bigint "mobilisation_campaign_id", null: false
    t.integer "payment_method"
    t.string "payment_reference"
    t.date "pledged_on", null: false
    t.bigint "recorded_by_id"
    t.string "reference", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["household_id"], name: "index_contributions_on_household_id"
    t.index ["mobilisation_campaign_id", "household_id"], name: "idx_on_mobilisation_campaign_id_household_id_7329a86ba0"
    t.index ["mobilisation_campaign_id"], name: "index_contributions_on_mobilisation_campaign_id"
    t.index ["payment_reference"], name: "index_contributions_on_payment_reference"
    t.index ["recorded_by_id"], name: "index_contributions_on_recorded_by_id"
    t.index ["reference"], name: "index_contributions_on_reference", unique: true
    t.index ["status"], name: "index_contributions_on_status"
  end

  create_table "conversations", force: :cascade do |t|
    t.string "channel", default: "whatsapp", null: false
    t.string "contact_number", null: false
    t.jsonb "context", default: {}, null: false
    t.datetime "created_at", null: false
    t.bigint "household_id"
    t.datetime "last_message_at"
    t.integer "message_count", default: 0, null: false
    t.string "state", default: "idle", null: false
    t.datetime "updated_at", null: false
    t.index ["contact_number", "channel"], name: "index_conversations_on_contact_number_and_channel", unique: true
    t.index ["household_id"], name: "index_conversations_on_household_id"
  end

  create_table "feedbacks", force: :cascade do |t|
    t.integer "category", default: 0, null: false
    t.string "contact_method"
    t.datetime "created_at", null: false
    t.datetime "handled_at"
    t.bigint "handled_by_id"
    t.text "message", null: false
    t.string "name"
    t.text "response"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["category"], name: "index_feedbacks_on_category"
    t.index ["handled_by_id"], name: "index_feedbacks_on_handled_by_id"
    t.index ["status"], name: "index_feedbacks_on_status"
  end

  create_table "households", force: :cascade do |t|
    t.integer "capture_source", default: 0, null: false
    t.bigint "captured_by_id"
    t.string "contact_number"
    t.datetime "created_at", null: false
    t.date "last_confirmed_on"
    t.text "location_description"
    t.string "name", null: false
    t.string "pin_digest"
    t.integer "pin_failed_attempts", default: 0, null: false
    t.bigint "pin_issued_by_id"
    t.datetime "pin_locked_until"
    t.datetime "pin_set_at"
    t.boolean "pin_temporary", default: false, null: false
    t.string "principal_contact"
    t.string "reference", null: false
    t.integer "status", default: 0, null: false
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.datetime "verified_at"
    t.bigint "verified_by_id"
    t.index ["captured_by_id"], name: "index_households_on_captured_by_id"
    t.index ["contact_number"], name: "index_households_on_contact_number"
    t.index ["name", "location_description"], name: "index_households_on_name_and_location"
    t.index ["pin_issued_by_id"], name: "index_households_on_pin_issued_by_id"
    t.index ["reference"], name: "index_households_on_reference", unique: true
    t.index ["status"], name: "index_households_on_status"
    t.index ["token"], name: "index_households_on_token", unique: true
    t.index ["verified_by_id"], name: "index_households_on_verified_by_id"
  end

  create_table "inbound_messages", force: :cascade do |t|
    t.text "body"
    t.string "channel", default: "whatsapp", null: false
    t.bigint "conversation_id"
    t.datetime "created_at", null: false
    t.string "from_number", null: false
    t.string "handled_as"
    t.text "handling_note"
    t.bigint "household_id"
    t.jsonb "payload", default: {}, null: false
    t.string "provider_message_id"
    t.datetime "received_at", null: false
    t.datetime "updated_at", null: false
    t.index ["conversation_id"], name: "index_inbound_messages_on_conversation_id"
    t.index ["from_number"], name: "index_inbound_messages_on_from_number"
    t.index ["household_id"], name: "index_inbound_messages_on_household_id"
    t.index ["provider_message_id"], name: "index_inbound_messages_on_provider_message_id", unique: true
  end

  create_table "mobilisation_campaigns", force: :cascade do |t|
    t.datetime "approved_at"
    t.bigint "approved_by_id"
    t.integer "campaign_type", default: 0, null: false
    t.date "closes_on"
    t.datetime "created_at", null: false
    t.string "currency", default: "USD", null: false
    t.string "name", null: false
    t.integer "obligation", default: 0, null: false
    t.date "opens_on", null: false
    t.text "purpose"
    t.string "receiving_account_detail"
    t.string "receiving_account_name"
    t.string "reference", null: false
    t.bigint "reporting_owner_id"
    t.integer "status", default: 0, null: false
    t.decimal "suggested_contribution", precision: 12, scale: 2
    t.decimal "target_amount", precision: 12, scale: 2
    t.string "target_description"
    t.datetime "updated_at", null: false
    t.index ["approved_by_id"], name: "index_mobilisation_campaigns_on_approved_by_id"
    t.index ["reference"], name: "index_mobilisation_campaigns_on_reference", unique: true
    t.index ["reporting_owner_id"], name: "index_mobilisation_campaigns_on_reporting_owner_id"
    t.index ["status"], name: "index_mobilisation_campaigns_on_status"
  end

  create_table "outbound_messages", force: :cascade do |t|
    t.integer "attempts", default: 0, null: false
    t.text "body", null: false
    t.string "channel", default: "whatsapp", null: false
    t.bigint "conversation_id"
    t.datetime "created_at", null: false
    t.datetime "delivered_at"
    t.boolean "disclosure", default: false, null: false
    t.text "error_message"
    t.bigint "household_id"
    t.string "provider_error_code"
    t.string "provider_message_id"
    t.string "provider_status"
    t.datetime "read_at"
    t.datetime "sent_at"
    t.string "skip_reason"
    t.integer "status", default: 0, null: false
    t.string "template_key"
    t.string "to_number", null: false
    t.datetime "updated_at", null: false
    t.index ["conversation_id"], name: "index_outbound_messages_on_conversation_id"
    t.index ["household_id"], name: "index_outbound_messages_on_household_id"
    t.index ["provider_message_id"], name: "index_outbound_messages_on_provider_message_id"
    t.index ["status"], name: "index_outbound_messages_on_status"
    t.index ["template_key"], name: "index_outbound_messages_on_template_key"
    t.index ["to_number"], name: "index_outbound_messages_on_to_number"
  end

  create_table "people", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.integer "age_band"
    t.string "contact_method"
    t.string "contact_number"
    t.datetime "created_at", null: false
    t.bigint "household_id", null: false
    t.string "name", null: false
    t.integer "relationship", default: 0, null: false
    t.integer "residency_status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.integer "year_of_birth"
    t.index ["contact_number"], name: "index_people_on_contact_number"
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

  create_table "receipts", force: :cascade do |t|
    t.decimal "amount", precision: 12, scale: 2
    t.bigint "captured_by_id"
    t.bigint "contribution_id", null: false
    t.datetime "created_at", null: false
    t.string "external_reference"
    t.date "issued_on", null: false
    t.text "note"
    t.integer "payment_rail", default: 0, null: false
    t.string "proof_link"
    t.string "reference", null: false
    t.datetime "updated_at", null: false
    t.integer "verification_status", default: 0, null: false
    t.datetime "verified_at"
    t.bigint "verified_by_id"
    t.index ["captured_by_id"], name: "index_receipts_on_captured_by_id"
    t.index ["contribution_id"], name: "index_receipts_on_contribution_id"
    t.index ["external_reference"], name: "index_receipts_on_external_reference"
    t.index ["reference"], name: "index_receipts_on_reference", unique: true
    t.index ["verification_status"], name: "index_receipts_on_verification_status"
    t.index ["verified_by_id"], name: "index_receipts_on_verified_by_id"
  end

  create_table "registration_requests", force: :cascade do |t|
    t.string "contact_method"
    t.string "contact_number"
    t.datetime "created_at", null: false
    t.datetime "handled_at"
    t.bigint "handled_by_id"
    t.bigint "household_id"
    t.string "location_hint"
    t.string "name", null: false
    t.text "note"
    t.text "outcome_note"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["contact_number"], name: "index_registration_requests_on_contact_number"
    t.index ["handled_by_id"], name: "index_registration_requests_on_handled_by_id"
    t.index ["household_id"], name: "index_registration_requests_on_household_id"
    t.index ["status"], name: "index_registration_requests_on_status"
  end

  create_table "solid_cache_entries", force: :cascade do |t|
    t.integer "byte_size", null: false
    t.datetime "created_at", null: false
    t.binary "key", null: false
    t.bigint "key_hash", null: false
    t.binary "value", null: false
    t.index ["byte_size"], name: "index_solid_cache_entries_on_byte_size"
    t.index ["key_hash", "byte_size"], name: "index_solid_cache_entries_on_key_hash_and_byte_size"
    t.index ["key_hash"], name: "index_solid_cache_entries_on_key_hash", unique: true
  end

  create_table "solid_queue_batch_executions", force: :cascade do |t|
    t.bigint "batch_id", null: false
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.index ["batch_id"], name: "index_solid_queue_batch_executions_on_batch_id"
    t.index ["job_id"], name: "index_solid_queue_batch_executions_on_job_id", unique: true
  end

  create_table "solid_queue_batches", force: :cascade do |t|
    t.string "active_job_batch_id"
    t.integer "completed_jobs", default: 0, null: false
    t.datetime "created_at", null: false
    t.string "description"
    t.datetime "enqueued_at"
    t.datetime "failed_at"
    t.integer "failed_jobs", default: 0, null: false
    t.datetime "finished_at"
    t.text "metadata"
    t.text "on_failure"
    t.text "on_finish"
    t.text "on_success"
    t.integer "total_jobs", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["active_job_batch_id"], name: "index_solid_queue_batches_on_active_job_batch_id", unique: true
    t.index ["finished_at"], name: "index_solid_queue_batches_on_finished_at"
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.string "concurrency_key", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error"
    t.bigint "job_id", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "active_job_id"
    t.text "arguments"
    t.bigint "batch_id"
    t.string "class_name", null: false
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at"
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["batch_id"], name: "index_solid_queue_jobs_on_batch_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "queue_name", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "hostname"
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.text "metadata"
    t.string "name", null: false
    t.integer "pid", null: false
    t.bigint "supervisor_id"
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.datetime "run_at", null: false
    t.string "task_key", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.text "arguments"
    t.string "class_name"
    t.string "command", limit: 2048
    t.datetime "created_at", null: false
    t.text "description"
    t.string "key", null: false
    t.integer "priority", default: 0
    t.string "queue_name"
    t.string "schedule", null: false
    t.boolean "static", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.integer "value", default: 1, null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
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
  add_foreign_key "contributions", "households"
  add_foreign_key "contributions", "mobilisation_campaigns"
  add_foreign_key "contributions", "users", column: "recorded_by_id"
  add_foreign_key "conversations", "households"
  add_foreign_key "feedbacks", "users", column: "handled_by_id"
  add_foreign_key "households", "users", column: "captured_by_id"
  add_foreign_key "households", "users", column: "pin_issued_by_id"
  add_foreign_key "households", "users", column: "verified_by_id"
  add_foreign_key "inbound_messages", "conversations"
  add_foreign_key "inbound_messages", "households"
  add_foreign_key "mobilisation_campaigns", "users", column: "approved_by_id"
  add_foreign_key "mobilisation_campaigns", "users", column: "reporting_owner_id"
  add_foreign_key "outbound_messages", "conversations"
  add_foreign_key "outbound_messages", "households"
  add_foreign_key "people", "households"
  add_foreign_key "programme_cases", "households"
  add_foreign_key "programme_cases", "people", column: "beneficiary_id"
  add_foreign_key "programme_cases", "users", column: "opened_by_id"
  add_foreign_key "programme_cases", "users", column: "submitted_by_id"
  add_foreign_key "receipts", "contributions"
  add_foreign_key "receipts", "users", column: "captured_by_id"
  add_foreign_key "receipts", "users", column: "verified_by_id"
  add_foreign_key "registration_requests", "households"
  add_foreign_key "registration_requests", "users", column: "handled_by_id"
  add_foreign_key "solid_queue_batch_executions", "solid_queue_batches", column: "batch_id", on_delete: :cascade
  add_foreign_key "solid_queue_batch_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
end
