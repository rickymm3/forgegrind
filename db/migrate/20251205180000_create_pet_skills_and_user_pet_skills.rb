class CreatePetSkillsAndUserPetSkills < ActiveRecord::Migration[8.0]
  def change
    create_table :pet_skills do |t|
      t.string  :name,        null: false
      t.string  :key,         null: false
      t.string  :rarity,      null: false, default: "common"
      t.text    :description
      t.string  :family
      t.integer :tier,        null: false, default: 1
      t.string  :effect_key
      t.jsonb   :effect_value, default: {}
      t.jsonb   :requirements, default: {}

      t.timestamps
    end
    add_index :pet_skills, :key, unique: true
    add_index :pet_skills, [:family, :tier]

    create_table :user_pet_skills do |t|
      t.references :user,       null: false, foreign_key: true
      t.references :pet_skill,  null: false, foreign_key: true
      t.integer    :tier,       null: false, default: 1
      t.integer    :quantity,   null: false, default: 1
      t.references :equipped_user_pet, foreign_key: { to_table: :user_pets }
      t.integer    :equipped_slot

      t.timestamps
    end

    add_index :user_pet_skills, [:user_id, :pet_skill_id, :tier], name: "index_user_pet_skills_on_user_and_skill_and_tier"
    add_index :user_pet_skills, [:equipped_user_pet_id, :equipped_slot], unique: true, where: "equipped_user_pet_id IS NOT NULL AND equipped_slot IS NOT NULL", name: "index_user_pet_skills_on_equipped_slot_unique"

    add_column :user_pets, :skill_slots, :integer, null: false, default: 2
  end
end
