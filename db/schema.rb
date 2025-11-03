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

ActiveRecord::Schema[8.0].define(version: 2025_11_02_190000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "abilities", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "element_type"
    t.string "reference", null: false
    t.index ["reference"], name: "index_abilities_on_reference", unique: true
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

  create_table "battle_sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "world_id", null: false
    t.integer "current_enemy_index", default: 0, null: false
    t.integer "player_hp", null: false
    t.string "status", default: "in_progress", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "enemy_hp", default: 0, null: false
    t.datetime "last_sync_at", default: -> { "now()" }, null: false
    t.jsonb "ability_cooldowns", default: {}, null: false
    t.index ["user_id"], name: "index_battle_sessions_on_user_id"
    t.index ["world_id"], name: "index_battle_sessions_on_world_id"
  end

  create_table "battle_sessions_user_pets", id: false, force: :cascade do |t|
    t.bigint "battle_session_id", null: false
    t.bigint "user_pet_id", null: false
    t.index ["battle_session_id"], name: "index_bs_up_on_bs"
    t.index ["user_pet_id"], name: "index_bs_up_on_up"
  end

  create_table "chest_types", force: :cascade do |t|
    t.string "key", null: false
    t.string "name", null: false
    t.string "icon", null: false
    t.bigint "default_loot_table_id", null: false
    t.boolean "open_batch_allowed", default: false, null: false
    t.integer "min_level", default: 1, null: false
    t.boolean "visible", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["default_loot_table_id"], name: "index_chest_types_on_default_loot_table_id"
    t.index ["key"], name: "index_chest_types_on_key", unique: true
  end

  create_table "container_open_events", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "chest_type_id", null: false
    t.integer "opened_qty", default: 0, null: false
    t.jsonb "rewards_json", default: [], null: false
    t.integer "latency_ms"
    t.string "client_version"
    t.string "request_uuid", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["chest_type_id"], name: "index_container_open_events_on_chest_type_id"
    t.index ["request_uuid"], name: "index_container_open_events_on_request_uuid", unique: true
    t.index ["user_id", "chest_type_id"], name: "index_container_open_events_on_user_id_and_chest_type_id"
    t.index ["user_id"], name: "index_container_open_events_on_user_id"
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

  create_table "enemies", force: :cascade do |t|
    t.bigint "world_id", null: false
    t.string "name", null: false
    t.integer "hp", default: 0, null: false
    t.integer "attack", default: 0, null: false
    t.integer "defense", default: 0, null: false
    t.integer "trophy_reward_base", default: 0, null: false
    t.integer "trophy_reward_growth", default: 0, null: false
    t.float "boss_bonus_multiplier", default: 1.0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["world_id"], name: "index_enemies_on_world_id"
  end

  create_table "evolution_rules", force: :cascade do |t|
    t.bigint "parent_pet_id", null: false
    t.bigint "child_pet_id", null: false
    t.integer "trigger_level"
    t.bigint "required_item_id"
    t.string "required_trait"
    t.float "required_trait_threshold"
    t.integer "required_play_count"
    t.integer "required_explorations"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "priority", default: 0, null: false
    t.integer "window_min_level"
    t.integer "window_max_level"
    t.string "window_event"
    t.jsonb "guard_json", default: {}, null: false
    t.boolean "one_shot", default: true, null: false
    t.string "seasonal_tag"
    t.text "notes"
    t.index ["child_pet_id"], name: "index_evolution_rules_on_child_pet_id"
    t.index ["parent_pet_id"], name: "index_evolution_rules_on_parent_pet_id"
    t.index ["required_item_id"], name: "index_evolution_rules_on_required_item_id"
  end

  create_table "generated_explorations", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "world_id", null: false
    t.string "base_key", null: false
    t.string "prefix_key"
    t.string "suffix_key"
    t.string "name", null: false
    t.jsonb "requirements", default: [], null: false
    t.jsonb "reward_config", default: {}, null: false
    t.jsonb "metadata", default: {}, null: false
    t.integer "duration_seconds", null: false
    t.datetime "scouted_at", null: false
    t.datetime "expires_at"
    t.datetime "consumed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "slot_index"
    t.datetime "cooldown_ends_at"
    t.jsonb "segment_definitions", default: [], null: false
    t.index ["user_id", "consumed_at"], name: "index_generated_explorations_on_user_id_and_consumed_at"
    t.index ["user_id", "slot_index"], name: "index_generated_explorations_on_user_and_slot", unique: true, where: "(slot_index IS NOT NULL)"
    t.index ["user_id"], name: "index_generated_explorations_on_user_id"
    t.index ["world_id"], name: "index_generated_explorations_on_world_id"
  end

  create_table "items", force: :cascade do |t|
    t.string "name", null: false
    t.string "item_type", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "loot_entries", force: :cascade do |t|
    t.bigint "loot_table_id", null: false
    t.bigint "item_id", null: false
    t.integer "weight", default: 1, null: false
    t.integer "qty_min", default: 1, null: false
    t.integer "qty_max", default: 1, null: false
    t.string "rarity", default: "common", null: false
    t.jsonb "constraints_json", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["item_id"], name: "index_loot_entries_on_item_id"
    t.index ["loot_table_id"], name: "index_loot_entries_on_loot_table_id"
  end

  create_table "loot_tables", force: :cascade do |t|
    t.string "key", null: false
    t.string "name", null: false
    t.integer "rolls_min", default: 1, null: false
    t.integer "rolls_max", default: 1, null: false
    t.jsonb "pity_config_json", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_loot_tables_on_key", unique: true
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
    t.text "description"
    t.bigint "special_ability_id"
    t.index ["default_ability_id"], name: "index_pets_on_default_ability_id"
    t.index ["egg_id"], name: "index_pets_on_egg_id"
    t.index ["rarity_id"], name: "index_pets_on_rarity_id"
    t.index ["special_ability_id"], name: "index_pets_on_special_ability_id"
  end

  create_table "rarities", force: :cascade do |t|
    t.string "name"
    t.string "color"
    t.integer "weight"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "glow_essence_multiplier", default: 1, null: false
  end

  create_table "special_abilities", force: :cascade do |t|
    t.string "reference", null: false
    t.string "name", null: false
    t.string "tagline"
    t.text "description"
    t.jsonb "encounter_tags", default: [], null: false
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["reference"], name: "index_special_abilities_on_reference", unique: true
  end

  create_table "user_containers", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "chest_type_id", null: false
    t.integer "count", default: 0, null: false
    t.string "acquired_source", default: "unknown", null: false
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["chest_type_id"], name: "index_user_containers_on_chest_type_id"
    t.index ["user_id", "chest_type_id"], name: "index_user_containers_on_user_id_and_chest_type_id", unique: true
    t.index ["user_id"], name: "index_user_containers_on_user_id"
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
    t.bigint "generated_exploration_id"
    t.bigint "primary_user_pet_id"
    t.jsonb "party_snapshot", default: {}, null: false
    t.jsonb "encounter_schedule", default: [], null: false
    t.datetime "encounters_seeded_at"
    t.jsonb "active_encounter", default: {}, null: false
    t.datetime "active_encounter_started_at"
    t.datetime "active_encounter_expires_at"
    t.jsonb "segment_progress", default: [], null: false
    t.integer "current_segment_index", default: 0, null: false
    t.datetime "segment_started_at"
    t.index ["generated_exploration_id"], name: "index_user_explorations_on_generated_exploration_id"
    t.index ["primary_user_pet_id"], name: "index_user_explorations_on_primary_user_pet_id"
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
    t.boolean "glow_infused", default: false, null: false
    t.index ["item_id"], name: "index_user_items_on_item_id"
    t.index ["user_id", "item_id"], name: "index_user_items_on_user_id_and_item_id", unique: true
    t.index ["user_id"], name: "index_user_items_on_user_id"
  end

  create_table "user_pet_abilities", force: :cascade do |t|
    t.bigint "user_pet_id", null: false
    t.bigint "ability_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "unlocked_via"
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
    t.integer "hunger", default: 70, null: false
    t.integer "hygiene", default: 70, null: false
    t.integer "boredom", default: 70, null: false
    t.integer "injury_level", default: 70, null: false
    t.integer "mood", default: 70, null: false
    t.datetime "needs_updated_at"
    t.jsonb "state_flags", default: {}, null: false
    t.jsonb "evolution_journal", default: {}, null: false
    t.jsonb "badges", default: [], null: false
    t.integer "care_good_days_count", default: 0, null: false
    t.date "last_good_day"
    t.datetime "retired_at"
    t.string "retired_reason"
    t.bigint "predecessor_user_pet_id"
    t.bigint "successor_user_pet_id"
    t.index ["egg_id"], name: "index_user_pets_on_egg_id"
    t.index ["held_user_item_id"], name: "index_user_pets_on_held_user_item_id"
    t.index ["pet_id"], name: "index_user_pets_on_pet_id"
    t.index ["pet_thought_id"], name: "index_user_pets_on_pet_thought_id"
    t.index ["predecessor_user_pet_id"], name: "index_user_pets_on_predecessor_user_pet_id"
    t.index ["rarity_id"], name: "index_user_pets_on_rarity_id"
    t.index ["retired_at"], name: "index_user_pets_on_retired_at"
    t.index ["successor_user_pet_id"], name: "index_user_pets_on_successor_user_pet_id"
    t.index ["user_id"], name: "index_user_pets_on_user_id"
  end

  create_table "user_stats", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.integer "energy", default: 0
    t.integer "trophies", default: 0
    t.integer "player_level", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "energy_updated_at"
    t.integer "hp_level", default: 1, null: false
    t.integer "attack_level", default: 1, null: false
    t.integer "defense_level", default: 1, null: false
    t.integer "luck_level", default: 1, null: false
    t.integer "attunement_level", default: 1, null: false
    t.integer "glow_essence", default: 0, null: false
    t.integer "diamonds", default: 0, null: false
    t.index ["user_id"], name: "index_user_stats_on_user_id"
  end

  create_table "user_worlds", id: false, force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "world_id", null: false
    t.index ["user_id", "world_id"], name: "index_user_worlds_on_user_id_and_world_id", unique: true
    t.index ["user_id"], name: "index_user_worlds_on_user_id"
    t.index ["world_id"], name: "index_user_worlds_on_world_id"
  end

  create_table "user_zone_completions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "world_id", null: false
    t.integer "times_cleared", default: 0, null: false
    t.datetime "last_completed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "world_id"], name: "index_user_zone_completions_on_user_id_and_world_id", unique: true
    t.index ["user_id"], name: "index_user_zone_completions_on_user_id"
    t.index ["world_id"], name: "index_user_zone_completions_on_world_id"
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
    t.datetime "last_scouted_at"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["last_scouted_at"], name: "index_users_on_last_scouted_at"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "worlds", force: :cascade do |t|
    t.string "name", null: false
    t.integer "duration", default: 0, null: false
    t.string "reward_item_type", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "enabled", default: true, null: false
    t.integer "diamond_reward", default: 0, null: false
    t.boolean "upgraded_on_clear", default: true, null: false
    t.jsonb "special_traits", default: [], null: false
    t.text "required_pet_abilities", default: [], null: false, array: true
    t.string "drop_table_override_key"
    t.text "upgrade_trait_keys", default: [], null: false, array: true
    t.text "upgrade_required_pet_abilities", default: [], null: false, array: true
    t.string "upgrade_drop_table_override_key"
    t.boolean "rotation_active", default: true, null: false
    t.integer "rotation_weight", default: 1, null: false
    t.datetime "rotation_starts_at"
    t.datetime "rotation_ends_at"
  end

  create_table "zone_chest_drops", force: :cascade do |t|
    t.bigint "world_id", null: false
    t.bigint "chest_type_id", null: false
    t.integer "weight", default: 100, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["chest_type_id"], name: "index_zone_chest_drops_on_chest_type_id"
    t.index ["world_id", "chest_type_id"], name: "index_zone_chest_drops_on_world_id_and_chest_type_id", unique: true
    t.index ["world_id"], name: "index_zone_chest_drops_on_world_id"
  end

  add_foreign_key "ability_effects", "abilities"
  add_foreign_key "ability_effects", "effects"
  add_foreign_key "ability_permissions", "abilities"
  add_foreign_key "battle_sessions", "users"
  add_foreign_key "battle_sessions", "worlds"
  add_foreign_key "battle_sessions_user_pets", "battle_sessions"
  add_foreign_key "battle_sessions_user_pets", "user_pets"
  add_foreign_key "chest_types", "loot_tables", column: "default_loot_table_id"
  add_foreign_key "container_open_events", "chest_types"
  add_foreign_key "container_open_events", "users"
  add_foreign_key "egg_item_costs", "eggs"
  add_foreign_key "egg_item_costs", "items"
  add_foreign_key "eggs", "currencies"
  add_foreign_key "enemies", "worlds"
  add_foreign_key "evolution_rules", "items", column: "required_item_id"
  add_foreign_key "evolution_rules", "pets", column: "child_pet_id"
  add_foreign_key "evolution_rules", "pets", column: "parent_pet_id"
  add_foreign_key "generated_explorations", "users"
  add_foreign_key "generated_explorations", "worlds"
  add_foreign_key "loot_entries", "items"
  add_foreign_key "loot_entries", "loot_tables"
  add_foreign_key "pets", "abilities", column: "default_ability_id"
  add_foreign_key "pets", "eggs"
  add_foreign_key "pets", "rarities"
  add_foreign_key "pets", "special_abilities"
  add_foreign_key "user_containers", "chest_types"
  add_foreign_key "user_containers", "users"
  add_foreign_key "user_eggs", "eggs"
  add_foreign_key "user_eggs", "users"
  add_foreign_key "user_explorations", "generated_explorations"
  add_foreign_key "user_explorations", "user_pets", column: "primary_user_pet_id"
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
  add_foreign_key "user_pets", "user_pets", column: "predecessor_user_pet_id", on_delete: :nullify
  add_foreign_key "user_pets", "user_pets", column: "successor_user_pet_id", on_delete: :nullify
  add_foreign_key "user_pets", "users"
  add_foreign_key "user_stats", "users"
  add_foreign_key "user_worlds", "users"
  add_foreign_key "user_worlds", "worlds"
  add_foreign_key "user_zone_completions", "users"
  add_foreign_key "user_zone_completions", "worlds"
  add_foreign_key "zone_chest_drops", "chest_types"
  add_foreign_key "zone_chest_drops", "worlds"
end
