class UserEgg < ApplicationRecord
  belongs_to :user
  belongs_to :egg

  scope :unhatched, -> { where(hatched: false) }
  after_commit :schedule_ready_notification!, if: :saved_change_to_hatch_started_at?

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

  def notify_ready_for_hatching!(force: false)
    return unless user
    return unless force || ready_to_hatch?

    existing = user.user_notifications
                   .unread
                   .where(category: "egg_ready")
                   .where("metadata ->> 'user_egg_id' = ?", id.to_s)
    return if existing.exists?

    metadata = {
      "user_egg_id" => id,
      "egg_id" => egg_id,
      "egg_name" => egg&.name,
      "hatch_started_at" => hatch_started_at&.iso8601
    }.compact

    user.user_notifications.create!(
      category: "egg_ready",
      title: "#{egg&.name || 'Your'} egg is ready",
      body: "Open it now to meet your new companion.",
      action_path: egg_ready_notification_path,
      metadata: metadata
    )
  rescue StandardError => e
    Rails.logger.debug { "[UserEgg] Failed to create ready notification for egg ##{id}: #{e.message}" }
    nil
  end

  def schedule_ready_notification!
    return unless hatching?

    duration_seconds = egg&.hatch_duration.to_i
    return notify_ready_for_hatching!(force: true) if duration_seconds <= 0
    return unless hatch_started_at.present?

    ready_at = hatch_started_at + duration_seconds.seconds
    EggReadyNotificationJob.set(wait_until: ready_at).perform_later(id)
  rescue StandardError => e
    Rails.logger.debug { "[UserEgg] Failed to schedule ready notification for egg ##{id}: #{e.message}" }
    nil
  end

  private

  def egg_ready_notification_path
    Rails.application.routes.url_helpers.user_pets_path(collection: "eggs")
  rescue StandardError
    "/user_pets?collection=eggs"
  end
end
