class TimelineController < ApplicationController
  def index
    @posts = Post.where(user_id: current_user.id)
                 .includes(deliveries: :provider_account)
                 .order(created_at: :desc)
                 .limit(100)

    Delivery.enqueue_stale_engagement_syncs(@posts.flat_map(&:deliveries))
  end
end
