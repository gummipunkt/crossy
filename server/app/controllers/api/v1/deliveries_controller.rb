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

      # POST /api/v1/posts/:post_id/deliveries/:id/retry
      def redeliver
        post = current_user.posts.find(params[:post_id])
        delivery = post.deliveries.find(params[:id])

        if delivery.retry!
          render json: { delivery: delivery_payload(delivery) }, status: :accepted
        else
          render json: { error: "Only failed deliveries can be retried" }, status: :unprocessable_entity
        end
      end
    end
  end
end
