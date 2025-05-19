class UserExploration < ApplicationRecord
  belongs_to :user
  belongs_to :world

  validates :started_at, presence: true

  def timer_expired?
    Time.current >= started_at + world.duration.seconds
  end

  def explore_time_remaining
    remaining = world.duration - (Time.current - started_at).to_i
    [remaining, 0].max
  end

  def complete?
    timer_expired? && completed_at.nil?
  end
end
