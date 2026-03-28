module Api
  module V1
    class PostsController < BaseController
      def create
        post = current_user.posts.create!(
          content_text: params.require(:content_text),
          content_warning: params[:content_warning],
          media_slots: params[:media_slots] || []
        )

        provider_ids = Array(params[:provider_account_ids])
        provider_accounts = current_user.provider_accounts.where(id: provider_ids)

        deliveries = provider_accounts.map do |pa|
          Delivery.create!(post: post, provider_account: pa, status: "queued", dedup_key: SecureRandom.uuid)
        end

        deliveries.each { |d| PostDeliveryJob.perform_later(d.id) }

        render json: { id: post.id, deliveries: deliveries.map { |d| { id: d.id, provider: d.provider_account.provider, status: d.status } } }, status: :accepted
      end

      def show
        post = current_user.posts.find(params[:id])
        render json: { id: post.id, content_text: post.content_text }
      end
    end
  end
end
