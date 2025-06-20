class Enemy < ApplicationRecord
  belongs_to :world

  validates :name, presence: true
  validates :hp, :attack, :defense,
            :trophy_reward_base, :trophy_reward_growth,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :boss_bonus_multiplier,
            numericality: { greater_than_or_equal_to: 0.0 }
end
