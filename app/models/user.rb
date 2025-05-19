class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable
  has_one :user_stat, dependent: :destroy
  has_many :user_eggs, dependent: :destroy
  has_many :user_pets, dependent: :destroy
  has_many :user_explorations, dependent: :destroy
  has_many :user_items, dependent: :destroy

  after_create :build_default_stats
  after_create :give_starter_egg

  def admin?
    self.admin
  end

  def can_afford_egg?(egg)
    egg.egg_item_costs.all? do |cost|
      user_items.joins(:item).where(items: { id: cost.item_id }).sum(:quantity) >= cost.quantity
    end
  end

  def spend_items_for_egg!(egg)
    egg.egg_item_costs.each do |cost|
      user_item = user_items.find_by(item_id: cost.item_id)
  
      raise ActiveRecord::Rollback, "Not enough #{cost.item.name}" if user_item.nil? || user_item.quantity < cost.quantity
  
      user_item.update!(quantity: user_item.quantity - cost.quantity)
    end
  end

  private

  def build_default_stats
    create_user_stat
  end
  
  def give_starter_egg
    starter = Egg.find_by(name: "Starter Egg")
    return unless starter
    user_eggs.create!(egg: starter, hatched: false, hatch_started_at: nil)
  end
  
end
