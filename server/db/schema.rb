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

ActiveRecord::Schema[8.0].define(version: 2025_10_15_150000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "deliveries", force: :cascade do |t|
    t.bigint "post_id", null: false
    t.bigint "provider_account_id", null: false
    t.string "status", default: "queued", null: false
    t.string "provider_post_id"
    t.text "error_message"
    t.string "dedup_key"
    t.datetime "started_at"
    t.datetime "finished_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["dedup_key"], name: "index_deliveries_on_dedup_key", unique: true
    t.index ["post_id", "provider_account_id"], name: "index_deliveries_on_post_id_and_provider_account_id", unique: true
    t.index ["post_id"], name: "index_deliveries_on_post_id"
    t.index ["provider_account_id"], name: "index_deliveries_on_provider_account_id"
  end

  create_table "media_attachments", force: :cascade do |t|
    t.bigint "post_id", null: false
    t.string "filename", null: false
    t.string "content_type", null: false
    t.integer "byte_size"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["post_id"], name: "index_media_attachments_on_post_id"
  end

  create_table "nostr_connect_sessions", force: :cascade do |t|
    t.bigint "provider_account_id", null: false
    t.string "status", default: "pending", null: false
    t.string "app_public_key", null: false
    t.text "app_private_key_enc"
    t.text "relay_secret_enc"
    t.text "relays_json", default: "[]", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["provider_account_id", "status"], name: "index_nostr_connect_sessions_on_provider_account_id_and_status"
    t.index ["provider_account_id"], name: "index_nostr_connect_sessions_on_provider_account_id"
  end

  create_table "posts", force: :cascade do |t|
    t.text "content_text", null: false
    t.text "content_warning"
    t.jsonb "media_slots", default: [], null: false
    t.datetime "scheduled_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "provider_accounts", force: :cascade do |t|
    t.string "provider", null: false
    t.string "handle", null: false
    t.string "instance"
    t.text "scopes"
    t.string "status", default: "active", null: false
    t.string "public_key"
    t.text "private_key_enc"
    t.bigint "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "access_token_ciphertext"
    t.text "refresh_token_ciphertext"
    t.string "handle_bidx"
    t.index ["handle_bidx"], name: "index_provider_accounts_on_handle_bidx"
    t.index ["provider", "handle", "instance"], name: "idx_provider_accounts_identity", unique: true
    t.index ["user_id"], name: "index_provider_accounts_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "display_name"
    t.boolean "two_factor_enabled", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "deliveries", "posts"
  add_foreign_key "deliveries", "provider_accounts"
  add_foreign_key "media_attachments", "posts"
  add_foreign_key "nostr_connect_sessions", "provider_accounts"
  add_foreign_key "provider_accounts", "users"
end
