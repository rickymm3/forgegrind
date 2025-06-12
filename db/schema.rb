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

ActiveRecord::Schema[8.0].define(version: 2025_06_12_165927) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "abilities", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.integer "power"
    t.integer "cost"
    t.integer "cooldown"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "damage", default: 0, null: false
    t.string "element_type"
  end

  create_table "ability_effects", force: :cascade do |t|
    t.bigint "ability_id", null: false
    t.bigint "effect_id", null: false
    t.integer "magnitude", default: 0, null: false
    t.integer "duration", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ability_id", "effect_id"], name: "index_ability_effects_on_ability_and_effect", unique: true
    t.index ["ability_id"], name: "index_ability_effects_on_ability_id"
    t.index ["effect_id"], name: "index_ability_effects_on_effect_id"
  end

  create_table "ability_permissions", force: :cascade do |t|
    t.bigint "ability_id", null: false
    t.string "permitted_type", null: false
    t.bigint "permitted_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ability_id"], name: "index_ability_permissions_on_ability_id"
    t.index ["permitted_type", "permitted_id"], name: "index_ability_permissions_on_permitted"
    t.index ["permitted_type", "permitted_id"], name: "index_permissions_on_permitted"
  end

  create_table "currencies", force: :cascade do |t|
    t.string "name"
    t.string "symbol"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "effects", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "egg_item_costs", force: :cascade do |t|
    t.bigint "egg_id", null: false
    t.bigint "item_id", null: false
    t.integer "quantity"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["egg_id"], name: "index_egg_item_costs_on_egg_id"
    t.index ["item_id"], name: "index_egg_item_costs_on_item_id"
  end

  create_table "eggs", force: :cascade do |t|
    t.string "name"
    t.integer "cost_amount"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "currency_id"
    t.integer "hatch_duration"
    t.boolean "enabled", default: true, null: false
    t.index ["currency_id"], name: "index_eggs_on_currency_id"
  end

  create_table "evolution_rules", force: :cascade do |t|
    t.bigint "parent_pet_id", null: false
    t.bigint "child_pet_id", null: false
    t.integer "trigger_level", null: false
    t.bigint "required_item_id"
    t.string "required_trait"
    t.float "required_trait_threshold"
    t.integer "required_play_count"
    t.integer "required_explorations"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["child_pet_id"], name: "index_evolution_rules_on_child_pet_id"
    t.index ["parent_pet_id"], name: "index_evolution_rules_on_parent_pet_id"
    t.index ["required_item_id"], name: "index_evolution_rules_on_required_item_id"
  end

  create_table "items", force: :cascade do |t|
    t.string "name", null: false
    t.string "item_type", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "pet_thoughts", force: :cascade do |t|
    t.string "thought"
    t.float "playfulness_mod"
    t.float "affection_mod"
    t.float "temperament_mod"
    t.float "curiosity_mod"
    t.float "confidence_mod"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "pet_types", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "pet_types_pets", id: false, force: :cascade do |t|
    t.bigint "pet_id", null: false
    t.bigint "pet_type_id", null: false
    t.index ["pet_id"], name: "index_pet_types_pets_on_pet_id"
    t.index ["pet_type_id"], name: "index_pet_types_pets_on_pet_type_id"
  end

  create_table "pet_types_worlds", id: false, force: :cascade do |t|
    t.bigint "world_id", null: false
    t.bigint "pet_type_id", null: false
    t.index ["pet_type_id"], name: "index_pet_types_worlds_on_pet_type_id"
    t.index ["world_id"], name: "index_pet_types_worlds_on_world_id"
  end

  create_table "pets", force: :cascade do |t|
    t.string "name"
    t.integer "power"
    t.bigint "egg_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "rarity_id"
    t.integer "hp", default: 5, null: false
    t.integer "atk", default: 5, null: false
    t.integer "def", default: 5, null: false
    t.integer "sp_atk", default: 5, null: false
    t.integer "sp_def", default: 5, null: false
    t.integer "speed", default: 5, null: false
    t.bigint "default_ability_id"
    t.index ["default_ability_id"], name: "index_pets_on_default_ability_id"
    t.index ["egg_id"], name: "index_pets_on_egg_id"
    t.index ["rarity_id"], name: "index_pets_on_rarity_id"
  end

  create_table "rarities", force: :cascade do |t|
    t.string "name"
    t.string "color"
    t.integer "weight"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "user_eggs", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "egg_id", null: false
    t.boolean "hatched"
    t.datetime "hatch_started_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["egg_id"], name: "index_user_eggs_on_egg_id"
    t.index ["user_id"], name: "index_user_eggs_on_user_id"
  end

  create_table "user_explorations", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "world_id", null: false
    t.datetime "started_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "completed_at"
    t.index ["user_id"], name: "index_user_explorations_on_user_id"
    t.index ["world_id"], name: "index_user_explorations_on_world_id"
  end

  create_table "user_explorations_pets", id: false, force: :cascade do |t|
    t.bigint "user_exploration_id", null: false
    t.bigint "user_pet_id", null: false
    t.index ["user_exploration_id", "user_pet_id"], name: "index_explorations_pets_on_ids"
    t.index ["user_pet_id", "user_exploration_id"], name: "index_pets_explorations_on_ids"
  end

  create_table "user_items", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "item_id", null: false
    t.integer "quantity", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["item_id"], name: "index_user_items_on_item_id"
    t.index ["user_id", "item_id"], name: "index_user_items_on_user_id_and_item_id", unique: true
    t.index ["user_id"], name: "index_user_items_on_user_id"
  end

  create_table "user_pet_abilities", force: :cascade do |t|
    t.bigint "user_pet_id", null: false
    t.bigint "ability_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ability_id"], name: "index_user_pet_abilities_on_ability_id"
    t.index ["user_pet_id", "ability_id"], name: "index_user_pet_abilities_on_user_pet_and_ability", unique: true
    t.index ["user_pet_id"], name: "index_user_pet_abilities_on_user_pet_id"
  end

  create_table "user_pets", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "pet_id", null: false
    t.bigint "egg_id", null: false
    t.string "name"
    t.bigint "rarity_id", null: false
    t.integer "power"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "equipped", default: false
    t.integer "playfulness"
    t.integer "affection"
    t.integer "temperament"
    t.integer "curiosity"
    t.integer "confidence"
    t.bigint "pet_thought_id", null: false
    t.datetime "last_interacted_at"
    t.integer "level", default: 1, null: false
    t.integer "exp", default: 0, null: false
    t.integer "interactions_remaining", default: 5, null: false
    t.integer "energy", default: 100, null: false
    t.datetime "asleep_until"
    t.datetime "last_energy_update_at"
    t.bigint "held_user_item_id"
    t.index ["egg_id"], name: "index_user_pets_on_egg_id"
    t.index ["held_user_item_id"], name: "index_user_pets_on_held_user_item_id"
    t.index ["pet_id"], name: "index_user_pets_on_pet_id"
    t.index ["pet_thought_id"], name: "index_user_pets_on_pet_thought_id"
    t.index ["rarity_id"], name: "index_user_pets_on_rarity_id"
    t.index ["user_id"], name: "index_user_pets_on_user_id"
  end

  create_table "user_stats", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.integer "energy", default: 0
    t.integer "trophies", default: 0
    t.integer "rebirths", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "energy_updated_at"
    t.index ["user_id"], name: "index_user_stats_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "admin", default: false, null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "worlds", force: :cascade do |t|
    t.string "name", null: false
    t.integer "duration", default: 0, null: false
    t.string "reward_item_type", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "ability_effects", "abilities"
  add_foreign_key "ability_effects", "effects"
  add_foreign_key "ability_permissions", "abilities"
  add_foreign_key "egg_item_costs", "eggs"
  add_foreign_key "egg_item_costs", "items"
  add_foreign_key "eggs", "currencies"
  add_foreign_key "evolution_rules", "items", column: "required_item_id"
  add_foreign_key "evolution_rules", "pets", column: "child_pet_id"
  add_foreign_key "evolution_rules", "pets", column: "parent_pet_id"
  add_foreign_key "pets", "abilities", column: "default_ability_id"
  add_foreign_key "pets", "eggs"
  add_foreign_key "pets", "rarities"
  add_foreign_key "user_eggs", "eggs"
  add_foreign_key "user_eggs", "users"
  add_foreign_key "user_explorations", "users"
  add_foreign_key "user_explorations", "worlds"
  add_foreign_key "user_items", "items"
  add_foreign_key "user_items", "users"
  add_foreign_key "user_pet_abilities", "abilities"
  add_foreign_key "user_pet_abilities", "user_pets"
  add_foreign_key "user_pets", "eggs"
  add_foreign_key "user_pets", "pet_thoughts"
  add_foreign_key "user_pets", "pets"
  add_foreign_key "user_pets", "rarities"
  add_foreign_key "user_pets", "user_items", column: "held_user_item_id"
  add_foreign_key "user_pets", "users"
  add_foreign_key "user_stats", "users"
end
