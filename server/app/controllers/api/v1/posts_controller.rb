module Api
  module V1
    class PostsController < ApplicationController
      protect_from_forgery with: :null_session

      def create
        post = Post.create!(content_text: params.require(:content_text), content_warning: params[:content_warning], media_slots: params[:media_slots] || [])

        provider_ids = Array(params[:provider_account_ids])
        provider_accounts = ProviderAccount.where(id: provider_ids)

        deliveries = provider_accounts.map do |pa|
          Delivery.create!(post: post, provider_account: pa, status: "queued", dedup_key: SecureRandom.uuid)
        end

        deliveries.each { |d| PostDeliveryJob.perform_later(d.id) }

        render json: { id: post.id, deliveries: deliveries.map { |d| { id: d.id, provider: d.provider_account.provider, status: d.status } } }, status: :accepted
      end

      def show
        post = Post.find(params[:id])
        render json: { id: post.id, content_text: post.content_text }
      end
    end
  end
end
