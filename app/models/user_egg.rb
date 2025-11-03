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

  def ready_to_hatch?
    hatching? && hatch_time_remaining <= 0
  end

  def idle?
    !hatching? && !hatched?
  end

  def status
    return :hatched if hatched?
    return :ready if ready_to_hatch?
    return :in_progress if hatching?
    :idle
  end

  def status_label
    case status
    when :ready
      "Ready to Hatch"
    when :in_progress
      "In Progress"
    when :idle
      "No Activity"
    else
      "Hatched"
    end
  end
end
