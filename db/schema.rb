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

ActiveRecord::Schema[8.1].define(version: 2026_08_28_030200) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "expansions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "name_ja"
    t.string "scryfall_set_code", null: false
    t.datetime "updated_at", null: false
    t.index ["scryfall_set_code"], name: "index_expansions_on_scryfall_set_code", unique: true
  end

  create_table "identities", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "provider", null: false
    t.string "uid", null: false
    t.bigint "user_id", null: false
    t.index ["provider", "uid"], name: "index_identities_on_provider_and_uid", unique: true
    t.index ["user_id"], name: "index_identities_on_user_id"
  end

  create_table "invitations", force: :cascade do |t|
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.bigint "issued_by_id", null: false
    t.string "signup_token"
    t.datetime "signup_token_expires_at"
    t.integer "status", default: 0, null: false
    t.datetime "used_at"
    t.bigint "used_by_id"
    t.index ["code"], name: "index_invitations_on_code", unique: true
    t.index ["expires_at"], name: "index_invitations_on_expires_at"
    t.index ["issued_by_id"], name: "index_invitations_on_issued_by_id"
    t.index ["signup_token"], name: "index_invitations_on_signup_token", unique: true
    t.index ["status"], name: "index_invitations_on_status"
    t.index ["used_by_id"], name: "index_invitations_on_used_by_id"
  end

  create_table "trades", force: :cascade do |t|
    t.string "contact"
    t.string "contact_account"
    t.datetime "created_at", null: false
    t.text "memo"
    t.string "name"
    t.string "residue"
    t.datetime "updated_at", null: false
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email"
    t.string "password_digest"
    t.integer "role", default: 0, null: false
    t.datetime "updated_at", null: false
    t.string "username", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  create_table "wishlists", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "edition"
    t.string "expansion"
    t.boolean "foil"
    t.string "language"
    t.string "name"
    t.string "state"
    t.integer "trade_id"
    t.datetime "updated_at", null: false
    t.index ["trade_id"], name: "index_wishlists_on_trade_id"
  end

  add_foreign_key "identities", "users"
  add_foreign_key "invitations", "users", column: "issued_by_id"
  add_foreign_key "invitations", "users", column: "used_by_id"
end
