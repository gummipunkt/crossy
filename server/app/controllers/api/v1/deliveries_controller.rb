module Api
  module V1
    class DeliveriesController < BaseController
      def index
        post = current_user.posts.find(params[:post_id])
        render json: {
          deliveries: post.deliveries.includes(:provider_account).map { |d|
            {
              id: d.id,
              provider: d.provider_account.provider,
              handle: d.provider_account.handle,
              status: d.status,
              provider_post_id: d.provider_post_id,
              error_message: d.error_message,
              finished_at: d.finished_at&.iso8601
            }
          }
        }
      end
    end
  end
end
