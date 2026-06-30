module Api
  module V1
    class DeliveriesController < BaseController
      include Api::V1::Payloads

      def index
        post = current_user.posts.find(params[:post_id])
        deliveries = post.deliveries.includes(:provider_account, :replies, :reactions)
        enqueue_engagement_sync_if_stale(deliveries)
        render json: { deliveries: deliveries.map { |d| delivery_payload(d, include_engagement: true) } }
      end
    end
  end
end
