module Api
  module V1
    class DeliveriesController < BaseController
      def index
        post = current_user.posts.find(params[:post_id])
        render json: post.deliveries.includes(:provider_account).map { |d|
          {
            id: d.id,
            provider: d.provider_account.provider,
            status: d.status,
            provider_post_id: d.provider_post_id,
            error_message: d.error_message
          }
        }
      end
    end
  end
end
