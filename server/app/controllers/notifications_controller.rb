class NotificationsController < ApplicationController
  FEED_LIMIT = 60
  SYNC_WINDOW = 14.days # only auto-enqueue syncs for posts from the last 2 weeks

  def index
    @items = build_feed
    enqueue_recent_syncs

    if turbo_frame_request?
      render partial: "feed", locals: { items: @items }
    else
      render :index
    end
  end

  private

  def build_feed
    delivery_ids = current_user_delivery_ids
    return [] if delivery_ids.empty?

    replies = DeliveryReply
      .where(delivery_id: delivery_ids)
      .includes(delivery: [ :post, :provider_account ])
      .order(created_at: :desc)
      .limit(FEED_LIMIT)
      .to_a

    reactions = DeliveryReaction
      .where(delivery_id: delivery_ids)
      .includes(delivery: [ :post, :provider_account ])
      .order(created_at: :desc)
      .limit(FEED_LIMIT)
      .to_a

    (replies + reactions)
      .sort_by { |r| -(event_time(r).to_i) }
      .first(FEED_LIMIT)
  end

  def event_time(record)
    case record
    when DeliveryReply    then record.posted_at  || record.created_at
    when DeliveryReaction then record.reacted_at || record.created_at
    end
  end
  helper_method :event_time

  def current_user_delivery_ids
    Delivery.joins(:post).where(posts: { user_id: current_user.id }).pluck(:id)
  end

  def enqueue_recent_syncs
    Delivery.joins(:post, :provider_account)
            .where(posts: { user_id: current_user.id })
            .where("posts.created_at > ?", SYNC_WINDOW.ago)
            .find_each do |d|
      next unless d.engagement_syncable? && d.metrics_stale?
      SyncDeliveryEngagementJob.perform_later(d.id)
    end
  end
end
