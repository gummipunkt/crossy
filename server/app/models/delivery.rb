class Delivery < ApplicationRecord
  belongs_to :post
  belongs_to :provider_account
  has_many :replies, class_name: "DeliveryReply", dependent: :delete_all

  # Rails 8 Enum-Syntax (string-backed)
  enum :status, {
    queued: "queued",
    in_progress: "in_progress",
    awaiting_signature: "awaiting_signature",
    succeeded: "succeeded",
    failed: "failed"
  }, validate: true

  validates :status, presence: true

  METRICS_STALE_AFTER = 5.minutes

  def metrics_stale?
    metrics_fetched_at.nil? || metrics_fetched_at < METRICS_STALE_AFTER.ago
  end

  def engagement_syncable?
    succeeded? && provider_post_id.present? &&
      %w[mastodon bluesky threads].include?(provider_account.provider)
  end
end
