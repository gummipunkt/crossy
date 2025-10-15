module Api
  module V1
    class NostrController < ApplicationController
      protect_from_forgery with: :null_session

      # POST /api/v1/nostr/prepare_event
      # params: post_id, provider_account_id
      def prepare_event
        post = Post.find(params.require(:post_id))
        pa = ProviderAccount.find(params.require(:provider_account_id))
        raise "wrong provider" unless pa.provider == "nostr"

        event = Posting::NostrClient.new(pa).prepare_event(post)
        # mark delivery awaiting signature
        Delivery.where(post: post, provider_account: pa).update_all(status: "awaiting_signature")
        render json: { event: event }
      end

      # POST /api/v1/nostr/publish
      # body: { event: {...}, provider_account_id }
      def publish
        pa = ProviderAccount.find(params.require(:provider_account_id))
        raise "wrong provider" unless pa.provider == "nostr"
        event = params.require(:event).permit!.to_h
        Posting::NostrClient.new(pa).publish_signed_event!(event)
        Delivery.where(post_id: params[:post_id], provider_account: pa).update_all(status: "succeeded", provider_post_id: event["id"])
        render json: { ok: true }
      rescue => e
        Delivery.where(post_id: params[:post_id], provider_account: pa).update_all(status: "failed", error_message: e.message) rescue nil
        render json: { ok: false, error: e.message }, status: 422
      end
    end
  end
end


