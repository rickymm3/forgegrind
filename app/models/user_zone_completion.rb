class UserZoneCompletion < ApplicationRecord
  belongs_to :user
  belongs_to :world

  validates :times_cleared, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :for_user, ->(user) { where(user: user) }
  scope :for_world, ->(world) { where(world: world) }

  def record_clear!
    increment!(:times_cleared)
    touch(:last_completed_at)
  end

  def first_clear?
    times_cleared <= 1
  end
end
