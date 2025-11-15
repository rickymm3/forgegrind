class EggPetPicker
  RARITY_PRIORITY = {
    "common" => 1,
    "uncommon" => 2,
    "rare" => 3,
    "epic" => 4,
    "legendary" => 5,
    "mythic" => 6
  }.freeze

  def initialize(egg:, user:)
    @egg = egg
    @user = user
    @user_stat = user&.ensure_user_stat
    @rng = Random.new
  end

  def pick
    pets = egg.pets.includes(:rarity).to_a
    return pets.sample(random: rng) if pets.size <= 1

    level = hero_level
    entries = pets.map do |pet|
      base_weight = [pet.rarity&.weight, 1].compact.first.to_i
      weight = if level.positive?
                 multiplier = GameConfig.hatchers_luck_multiplier(level, rarity_rank(pet))
                 (base_weight * multiplier).round
               else
                 base_weight
               end
      { value: pet, weight: [weight, 1].max }
    end

    WeightedPicker.pick(entries, rng: rng) || pets.sample(random: rng)
  end

  private

  attr_reader :egg, :user, :user_stat, :rng

  def hero_level
    user_stat&.hero_upgrade_level(:hatchers_luck).to_i
  rescue StandardError
    0
  end

  def rarity_rank(pet)
    rarity_name = pet.rarity&.name
    RARITY_PRIORITY[rarity_name.to_s.downcase] || 1
  end
end
