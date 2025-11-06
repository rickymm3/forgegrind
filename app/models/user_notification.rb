class UserNotification < ApplicationRecord
  belongs_to :user

  scope :unread, -> { where(read_at: nil) }
  scope :recent_first, -> { order(created_at: :desc) }

  validates :category, presence: true
  validates :title, presence: true

  def mark_read!
    update!(read_at: Time.current)
  end

  def read?
    read_at.present?
  end

  def unread?
    !read?
  end
end
