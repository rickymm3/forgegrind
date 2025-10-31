class UserExploration < ApplicationRecord
  belongs_to :user
  belongs_to :world
  belongs_to :generated_exploration, optional: true
  has_and_belongs_to_many :user_pets,
                          -> { active },
                          join_table: "user_explorations_pets"
  
  validates :started_at, presence: true

  def timer_expired?
    Time.current >= started_at + duration_seconds.seconds
  end

  def explore_time_remaining
    remaining = duration_seconds - (Time.current - started_at).to_i
    [remaining, 0].max
  end

  def complete?
    timer_expired? && completed_at.nil?
  end

  def duration_seconds
    if generated_exploration.present?
      generated_exploration.duration_seconds
    else
      world.duration
    end
  end
end
