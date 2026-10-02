module Api
  module V1
    class TimelineController < BaseController
      def index
        limit = (params[:limit].presence || 50).to_i.clamp(1, 100)
        items = FeedAggregator.new.aggregate(limit: limit, user: current_user)
        render json: { items: items.map { |i| item_payload(i) } }
      end

      def action
        ok = FeedInteraction.new(current_user).perform!(
          provider: params.require(:provider),
          item_id: params.require(:id),
          action: params.require(:action_type),
          cid: params[:cid],
          provider_account_id: params[:provider_account_id]
        )

        if ok
          head :ok
        else
          render json: { error: "Provider rejected action" }, status: :unprocessable_entity
        end
      rescue FeedInteraction::UnsupportedAction => e
        render json: { error: e.message }, status: :bad_request
      rescue ActionController::ParameterMissing, ActiveRecord::RecordNotFound
        raise
      rescue => e
        Rails.logger.error("Timeline action error: #{e.message}")
        render json: { error: e.message }, status: :unprocessable_entity
      end

      private

      def item_payload(item)
        {
          provider: item.provider,
          provider_account_id: item.provider_account_id,
          id: item.id,
          author: item.author,
          content: item.content,
          created_at: item.created_at&.iso8601,
          url: item.url,
          images: item.images,
          avatar_url: item.avatar_url,
          likes_count: item.likes_count,
          reposts_count: item.reposts_count,
          replies_count: item.replies_count,
          liked_by_me: item.liked_by_me,
          reposted_by_me: item.reposted_by_me,
          bookmarked_by_me: item.bookmarked_by_me,
          cid: item.cid,
          reblogged_by: item.reblogged_by
        }
      end
    end
  end
end
