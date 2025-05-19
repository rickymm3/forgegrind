class UserEgg < ApplicationRecord
  belongs_to :user
  belongs_to :egg

  scope :unhatched, -> { where(hatched: false) }

  def hatching?
    hatch_started_at.present? && !hatched?
  end

  def hatch_time_remaining
    return 0 unless hatching?
    [egg.hatch_duration.seconds - (Time.current - hatch_started_at), 0].max
  end
end
