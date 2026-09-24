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

ActiveRecord::Schema[8.0].define(version: 1891_09_04_120000) do
  create_table "companies", force: :cascade do |t|
    t.string "name", null: false
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.date "registered_on"
    t.index ["code"], name: "index_companies_on_code", unique: true
  end

  create_table "consignments", force: :cascade do |t|
    t.string "reference", null: false
    t.string "description", null: false
    t.date "sent_on", null: false
    t.integer "pence", null: false
    t.integer "weight_lb", null: false
    t.boolean "settled", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "company_id", null: false
    t.index ["company_id"], name: "index_consignments_on_company_id"
    t.index ["reference"], name: "index_consignments_on_reference", unique: true
    t.check_constraint "pence > 0", name: "consignments_pence_positive"
    t.check_constraint "weight_lb > 0", name: "consignments_weight_positive"
  end

  create_table "entries", force: :cascade do |t|
    t.string "docket", null: false
    t.integer "position", null: false
    t.string "company_code", null: false
    t.string "station"
    t.integer "miles", null: false
    t.string "clerk", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "voided_at"
    t.index ["docket", "position"], name: "index_entries_on_docket_and_position"
    t.index ["docket", "position"], name: "index_entries_on_live_leg", unique: true, where: "voided_at IS NULL"
  end

  create_table "legs", force: :cascade do |t|
    t.integer "consignment_id", null: false
    t.integer "company_id", null: false
    t.integer "position", null: false
    t.integer "miles", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "role", default: 1, null: false
    t.index ["company_id"], name: "index_legs_on_company_id"
    t.index ["consignment_id", "position"], name: "index_legs_on_consignment_id_and_position", unique: true
    t.index ["consignment_id"], name: "index_legs_on_consignment_id"
    t.index ["consignment_id"], name: "index_legs_one_collector", unique: true, where: "role = 0"
    t.check_constraint "miles > 0", name: "legs_miles_positive"
    t.check_constraint "role IN (0, 1, 2)", name: "legs_role_known"
  end

  create_table "settlements", force: :cascade do |t|
    t.integer "company_id", null: false
    t.string "period", null: false
    t.integer "pence", null: false
    t.integer "state", default: 0, null: false
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "period"], name: "index_settlements_on_company_id_and_period", unique: true
    t.index ["company_id"], name: "index_settlements_on_company_id"
    t.check_constraint "pence > 0", name: "settlements_pence_positive"
    t.check_constraint "state IN (0, 1)", name: "settlements_state_known"
  end

  add_foreign_key "consignments", "companies"
  add_foreign_key "legs", "companies"
  add_foreign_key "legs", "consignments"
  add_foreign_key "settlements", "companies"
end
