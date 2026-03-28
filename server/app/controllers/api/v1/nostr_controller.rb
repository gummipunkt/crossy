module Api
  module V1
    class NostrController < BaseController
      # POST /api/v1/nostr/prepare_event
      # params: post_id, provider_account_id
      def prepare_event
        post = current_user.posts.find(params.require(:post_id))
        pa = current_user.provider_accounts.find(params.require(:provider_account_id))
        raise "wrong provider" unless pa.provider == "nostr"

        event = Posting::NostrClient.new(pa).prepare_event(post)
        # mark delivery awaiting signature
        Delivery.where(post: post, provider_account: pa).update_all(status: "awaiting_signature")
        render json: { event: event }
      end

      # POST /api/v1/nostr/publish
      # body: { post_id, event: {...}, provider_account_id }
      def publish
        post_id = nil
        pa = nil
        post_id = params.require(:post_id)
        pa = current_user.provider_accounts.find(params.require(:provider_account_id))
        raise "wrong provider" unless pa.provider == "nostr"

        current_user.posts.find(post_id)

        event = permitted_signed_nostr_event
        Posting::NostrClient.new(pa).publish_signed_event!(event)
        Delivery.where(post_id: post_id, provider_account: pa).update_all(status: "succeeded", provider_post_id: event["id"])
        render json: { ok: true }
      rescue ActiveRecord::RecordNotFound
        raise
      rescue => e
        if pa && post_id
          Delivery.where(post_id: post_id, provider_account: pa).update_all(status: "failed", error_message: e.message) rescue nil
        end
        render json: { ok: false, error: e.message }, status: :unprocessable_entity
      end

      private

      # NIP-01 signed event fields only; tags are arrays of string arrays (bounded).
      def permitted_signed_nostr_event
        e = params.require(:event)
        base = e.permit(:id, :pubkey, :created_at, :kind, :content, :sig).to_h
        tags = normalize_nostr_tags(e[:tags] || e["tags"])
        base.stringify_keys.merge("tags" => tags)
      end

      def normalize_nostr_tags(raw)
        return [] if raw.nil?

        raise ActionController::BadRequest, "tags must be an array" unless raw.is_a?(Array)
        raise ActionController::BadRequest, "too many tags" if raw.size > 32

        raw.map do |row|
          raise ActionController::BadRequest, "tag row must be an array" unless row.is_a?(Array)
          raise ActionController::BadRequest, "tag row too long" if row.size > 16

          row.map { |v| v.to_s }
        end
      end
    end
  end
end
