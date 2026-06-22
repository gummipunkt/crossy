class Post < ApplicationRecord
  belongs_to :user, optional: true
  has_many :deliveries, dependent: :destroy
  has_many :provider_accounts, through: :deliveries
  has_many :media_attachments, dependent: :destroy

  validates :content_text, presence: true

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
end
