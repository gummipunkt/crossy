class Delivery < ApplicationRecord
  belongs_to :post
  belongs_to :provider_account
  has_many :replies,   class_name: "DeliveryReply", dependent: :delete_all
  has_many :reactions, class_name: "DeliveryReaction", dependent: :delete_all
  has_many :likes,     -> { where(kind: "like") },   class_name: "DeliveryReaction"
  has_many :reposts,   -> { where(kind: "repost") }, class_name: "DeliveryReaction"

  # Rails 8 Enum-Syntax (string-backed)
  enum :status, {
    scheduled: "scheduled",
    queued: "queued",
    in_progress: "in_progress",
    awaiting_signature: "awaiting_signature",
    succeeded: "succeeded",
    failed: "failed"
  }, validate: true

  validates :status, presence: true

  METRICS_STALE_AFTER = 5.minutes

  # Page views and polling ask for fresh engagement constantly; enqueue at
  # most one sync per delivery per METRICS_STALE_AFTER. The timestamp is
  # claimed atomically so concurrent requests cannot both enqueue.
  def self.enqueue_stale_engagement_syncs(deliveries)
    deliveries.each do |delivery|
      next unless delivery.engagement_syncable? && delivery.metrics_stale?

      claimed = where(id: delivery.id)
                  .where("metrics_sync_enqueued_at IS NULL OR metrics_sync_enqueued_at < ?", METRICS_STALE_AFTER.ago)
                  .update_all(metrics_sync_enqueued_at: Time.current)
      SyncDeliveryEngagementJob.perform_later(delivery.id) if claimed == 1
    end
  end

  # Status a new delivery starts in. Nostr events are signed in the browser,
  # so they wait for the user; scheduled posts wait for DispatchScheduledPostsJob.
  def self.initial_status_for(provider_account, post)
    return "awaiting_signature" if provider_account.provider == "nostr"

    post.scheduled_for_later? ? "scheduled" : "queued"
  end

  # Moves scheduled deliveries whose post is due into the queue. Each one is
  # claimed atomically, so overlapping dispatcher runs cannot enqueue it twice.
  def self.dispatch_due!(scope = all)
    due = scope.scheduled.joins(:post).where(posts: { scheduled_at: ..Time.current })
    due.pluck(:id).count do |id|
      claimed = where(id: id, status: "scheduled").update_all(status: "queued", updated_at: Time.current)
      PostDeliveryJob.perform_later(id) if claimed == 1
      claimed == 1
    end
  end

  # Sends a failed delivery again. The dedup_key stays the same, so Mastodon
  # returns the original status if the first attempt did get through.
  def retry!
    return false unless failed?

    next_status = provider_account.provider == "nostr" ? "awaiting_signature" : "queued"
    claimed = self.class.where(id: id, status: "failed")
                        .update_all(status: next_status, error_message: nil, started_at: nil, finished_at: nil, updated_at: Time.current)
    return false unless claimed == 1

    PostDeliveryJob.perform_later(id) if next_status == "queued"
    reload
    true
  end

  def metrics_stale?
    metrics_fetched_at.nil? || metrics_fetched_at < METRICS_STALE_AFTER.ago
  end

  def engagement_syncable?
    succeeded? && provider_post_id.present? &&
      %w[mastodon bluesky threads].include?(provider_account.provider)
  end
end
