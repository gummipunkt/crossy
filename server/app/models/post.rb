class Post < ApplicationRecord
  belongs_to :user, optional: true
  has_many :deliveries, dependent: :destroy
  has_many :provider_accounts, through: :deliveries
  has_many :media_attachments, dependent: :destroy

  validates :content_text, presence: true
  before_validation :post_immediately_if_due, on: :create
  validate :scheduled_at_in_future, on: :create

  # Times this close to now are treated as "post immediately".
  SCHEDULE_GRACE = 1.minute

  def scheduled_for_later?
    scheduled_at.present? && scheduled_at > Time.current
  end

  def total_like_count
    deliveries.sum(&:like_count)
  end

  def total_reply_count
    deliveries.sum(&:reply_count)
  end

  def total_repost_count
    deliveries.sum(&:repost_count)
  end

  def engagement_last_synced_at
    deliveries.map(&:metrics_fetched_at).compact.max
  end

  private

  def post_immediately_if_due
    return if scheduled_at.blank?

    self.scheduled_at = nil if scheduled_at.between?(SCHEDULE_GRACE.ago, SCHEDULE_GRACE.from_now)
  end

  def scheduled_at_in_future
    errors.add(:scheduled_at, "must be in the future") if scheduled_at.present? && scheduled_at < Time.current
  end
end
