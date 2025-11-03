class World < ApplicationRecord
  has_many :user_explorations, dependent: :destroy
  has_and_belongs_to_many :pet_types
  has_many :user_zone_completions, dependent: :destroy
  has_many :enemies, -> { order(:id) }, dependent: :destroy
  has_and_belongs_to_many :users_who_unlocked, class_name: 'User', join_table: 'user_worlds'
  has_many :zone_chest_drops, dependent: :destroy

  validates :name, :duration, :reward_item_type, presence: true
  validates :duration, numericality: { only_integer: true, greater_than: 0 }
  validates :diamond_reward, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :active, -> { where(enabled: true) }
  scope :rotation_active, lambda {
    now = Time.current
    where(rotation_active: true)
      .where("rotation_starts_at IS NULL OR rotation_starts_at <= ?", now)
      .where("rotation_ends_at IS NULL OR rotation_ends_at >= ?", now)
  }

  def exploration_slug
    @exploration_slug ||= name.to_s.parameterize(separator: '-')
  end

  def currently_available?
    enabled? && self.class.rotation_active.where(id: id).exists?
  end

  def special_trait_keys
    Array(self[:special_traits]).map(&:to_s)
  end

  def trait_labels
    special_trait_keys.map { |key| ZoneTraitLibrary.label_for(key) }
  end

  def required_pet_ability_keys
    Array(self[:required_pet_abilities]).map(&:to_s)
  end

  def upgrade_trait_keys_list
    Array(self[:upgrade_trait_keys]).map(&:to_s)
  end

  def bonus_drop_bucket
    drop_table_override_key.presence
  end

  def matches_required_abilities?(user_pets)
    return false if required_pet_ability_keys.blank?

    ability_refs = user_pets.flat_map(&:ability_references).map(&:to_s).uniq
    (ability_refs & required_pet_ability_keys).any?
  end

  def aggregate_required_abilities(trait_keys)
    trait_keys.flat_map { |key| ZoneTraitLibrary.required_abilities_for(key) }.map(&:to_s).uniq
  end

  def aggregate_drop_override(trait_keys)
    trait_keys.map { |key| ZoneTraitLibrary.drop_table_key_for(key) }.compact.first
  end

  def determine_upgrade_abilities(keys)
    upgrade_required_pet_abilities.presence || aggregate_required_abilities(keys)
  end

  def determine_upgrade_drop_table(keys)
    upgrade_drop_table_override_key.presence || aggregate_drop_override(keys) || drop_table_override_key
  end

  def apply_upgrade_from_traits!
    keys = upgrade_trait_keys_list
    return if keys.blank?

    update!(
      special_traits: keys,
      required_pet_abilities: determine_upgrade_abilities(keys),
      drop_table_override_key: determine_upgrade_drop_table(keys)
    )
  end

  def pending_upgrade?
    upgraded_on_clear? && special_trait_keys.blank? && upgrade_trait_keys_list.present?
  end

  def activate_rotation!(starts_at: Time.current, ends_at: Time.current.end_of_day)
    update!(
      rotation_active: true,
      rotation_starts_at: starts_at,
      rotation_ends_at: ends_at
    )
  end

  def deactivate_rotation!
    update!(
      rotation_active: false,
      rotation_starts_at: nil,
      rotation_ends_at: nil
    )
  end
end
