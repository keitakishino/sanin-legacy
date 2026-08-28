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

ActiveRecord::Schema[8.1].define(version: 2026_08_29_000500) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "created_by_id", null: false, comment: "作成者（管理者）のuser_id。FK制約はIssue #28マージ後に別マイグレーションで追加"
    t.text "description", comment: "イベント説明"
    t.datetime "discarded_at", comment: "論理削除フラグ（null=有効、datetime=削除日時）"
    t.date "event_date", null: false, comment: "イベント開催日"
    t.string "spreadsheet_id", comment: "Google SheetsファイルID（初回エクスポート時に生成）"
    t.string "title", null: false, comment: "イベント名"
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_events_on_created_by_id"
    t.index ["discarded_at"], name: "index_events_on_discarded_at"
    t.index ["event_date", "discarded_at"], name: "index_events_on_event_date_and_discarded_at"
    t.index ["title"], name: "index_events_on_title"
  end

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

  create_table "trade_card_offers", force: :cascade do |t|
    t.integer "amount"
    t.string "card_name", null: false
    t.integer "condition", null: false
    t.datetime "created_at", null: false
    t.bigint "expansion_id"
    t.integer "foil", null: false
    t.integer "frame", null: false
    t.integer "language", null: false
    t.text "note"
    t.boolean "pw_mark", default: false, null: false
    t.integer "quantity", null: false
    t.bigint "trade_id", null: false
    t.datetime "updated_at", null: false
    t.index ["expansion_id"], name: "index_trade_card_offers_on_expansion_id"
    t.index ["trade_id"], name: "index_trade_card_offers_on_trade_id"
    t.check_constraint "quantity > 0", name: "trade_card_offers_quantity_positive"
  end

  create_table "trade_card_wants", force: :cascade do |t|
    t.integer "amount"
    t.string "card_name", null: false
    t.integer "conditions", array: true
    t.datetime "created_at", null: false
    t.bigint "expansion_id"
    t.integer "foil"
    t.integer "frame"
    t.integer "language"
    t.text "note"
    t.integer "quantity", null: false
    t.bigint "trade_id", null: false
    t.datetime "updated_at", null: false
    t.index ["expansion_id"], name: "index_trade_card_wants_on_expansion_id"
    t.index ["trade_id"], name: "index_trade_card_wants_on_trade_id"
    t.check_constraint "quantity > 0", name: "trade_card_wants_quantity_positive"
  end

  create_table "trades", force: :cascade do |t|
    t.text "cancelled_reason"
    t.datetime "completed_at"
    t.bigint "completed_by_id"
    t.datetime "created_at", null: false
    t.bigint "event_id", null: false
    t.integer "net_amount", default: 0, null: false
    t.integer "offers_total_amount", default: 0, null: false
    t.datetime "spreadsheet_exported_at"
    t.bigint "spreadsheet_exported_by_id"
    t.string "spreadsheet_tab_name"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.integer "wants_total_amount", default: 0, null: false
    t.index ["completed_by_id"], name: "index_trades_on_completed_by_id"
    t.index ["event_id", "user_id"], name: "index_trades_on_event_id_and_user_id", unique: true
    t.index ["event_id"], name: "index_trades_on_event_id"
    t.index ["spreadsheet_exported_by_id"], name: "index_trades_on_spreadsheet_exported_by_id"
    t.index ["user_id"], name: "index_trades_on_user_id"
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

  add_foreign_key "events", "users", column: "created_by_id"
  add_foreign_key "identities", "users"
  add_foreign_key "invitations", "users", column: "issued_by_id"
  add_foreign_key "invitations", "users", column: "used_by_id"
  add_foreign_key "trade_card_offers", "expansions"
  add_foreign_key "trade_card_offers", "trades"
  add_foreign_key "trade_card_wants", "expansions"
  add_foreign_key "trade_card_wants", "trades"
  add_foreign_key "trades", "events"
  add_foreign_key "trades", "users"
  add_foreign_key "trades", "users", column: "completed_by_id"
  add_foreign_key "trades", "users", column: "spreadsheet_exported_by_id"
end
