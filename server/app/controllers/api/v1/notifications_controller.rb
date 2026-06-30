module Api
  module V1
    class NotificationsController < BaseController
      DEFAULT_LIMIT = 60
      MAX_LIMIT     = 200
      SYNC_WINDOW   = 14.days

      def index
        limit = clamp_limit(params[:limit])
        items = build_feed(limit: limit)
        enqueue_recent_syncs

        render json: {
          items: items.map { |item| notification_payload(item) },
          fetched_at: Time.current.iso8601
        }
      end

      private

      def build_feed(limit:)
        delivery_ids = current_user_delivery_ids
        return [] if delivery_ids.empty?

        replies = DeliveryReply
          .where(delivery_id: delivery_ids)
          .includes(delivery: [ :post, :provider_account ])
          .order(created_at: :desc)
          .limit(limit)
          .to_a

        reactions = DeliveryReaction
          .where(delivery_id: delivery_ids)
          .includes(delivery: [ :post, :provider_account ])
          .order(created_at: :desc)
          .limit(limit)
          .to_a

        (replies + reactions)
          .sort_by { |r| -(event_time(r).to_i) }
          .first(limit)
      end

      def event_time(record)
        case record
        when DeliveryReply    then record.posted_at  || record.created_at
        when DeliveryReaction then record.reacted_at || record.created_at
        end
      end

      def current_user_delivery_ids
        Delivery.joins(:post).where(posts: { user_id: current_user.id }).pluck(:id)
      end

      def enqueue_recent_syncs
        Delivery.joins(:post, :provider_account)
                .where(posts: { user_id: current_user.id })
                .where("posts.created_at > ?", SYNC_WINDOW.ago)
                .find_each do |d|
          next unless d.engagement_syncable? && d.metrics_stale?
          SyncDeliveryEngagementJob.perform_later(d.id)
        end
      end

      def clamp_limit(raw)
        n = raw.to_i
        return DEFAULT_LIMIT if n <= 0
        [ n, MAX_LIMIT ].min
      end

      def notification_payload(item)
        delivery = item.delivery
        provider = delivery.provider_account.provider
        ts       = event_time(item)
        is_reply = item.is_a?(DeliveryReply)

        common = {
          id: item.id,
          kind: is_reply ? "reply" : item.kind,           # reply | like | repost
          provider: provider,                             # mastodon | bluesky | threads
          event_at: ts&.iso8601,
          observed_at: item.created_at.iso8601,
          post: {
            id: delivery.post_id,
            content_text: delivery.post.content_text
          },
          delivery_id: delivery.id,
          author: {
            handle: item.author_handle,
            name: item.author_name,
            avatar_url: item.author_avatar_url
          }
        }

        if is_reply
          common.merge(
            content: item.content,
            permalink: item.permalink
          )
        else
          common.merge(
            author: common[:author].merge(url: item.author_url)
          )
        end
      end
    end
  end
end
