class TimelineController < ApplicationController
  def index
    @posts = Post.where(user_id: current_user.id)
                 .includes(deliveries: :provider_account)
                 .order(created_at: :desc)
                 .limit(100)

    enqueue_stale_engagement_syncs(@posts)
  end

  private

  def enqueue_stale_engagement_syncs(posts)
    posts.flat_map(&:deliveries).each do |d|
      next unless d.engagement_syncable? && d.metrics_stale?
      SyncDeliveryEngagementJob.perform_later(d.id)
    end
  end
end
