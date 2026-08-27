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

ActiveRecord::Schema[8.1].define(version: 2026_08_27_175103) do
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

  create_table "trades", force: :cascade do |t|
    t.string "contact"
    t.string "contact_account"
    t.datetime "created_at", null: false
    t.text "memo"
    t.string "name"
    t.string "residue"
    t.datetime "updated_at", null: false
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
end
