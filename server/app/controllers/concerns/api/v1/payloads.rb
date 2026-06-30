module Api
  module V1
    module Payloads
      extend ActiveSupport::Concern

      INLINE_REPLIES_PER_DELIVERY   = 50
      INLINE_REACTIONS_PER_DELIVERY = 50

      def post_payload(post, include_totals: false)
        out = {
          id: post.id,
          content_text: post.content_text,
          content_warning: post.content_warning,
          created_at: post.created_at.iso8601
        }
        if include_totals
          out.merge!(
            engagement: {
              like_count: post.total_like_count,
              reply_count: post.total_reply_count,
              repost_count: post.total_repost_count,
              last_synced_at: post.engagement_last_synced_at&.iso8601
            }
          )
        end
        out
      end

      def delivery_payload(d, include_engagement: false)
        base = {
          id: d.id,
          provider: d.provider_account.provider,
          handle: d.provider_account.handle,
          status: d.status,
          provider_post_id: d.provider_post_id,
          error_message: d.error_message,
          finished_at: d.finished_at&.iso8601
        }
        return base unless include_engagement

        base.merge(engagement: engagement_payload(d))
      end

      def engagement_payload(d)
        {
          like_count: d.like_count,
          reply_count: d.reply_count,
          repost_count: d.repost_count,
          metrics_fetched_at: d.metrics_fetched_at&.iso8601,
          metrics_error: d.metrics_error,
          syncable: d.engagement_syncable?,
          replies: d.replies.order(posted_at: :desc, created_at: :desc).limit(INLINE_REPLIES_PER_DELIVERY).map { |r| reply_payload(r) },
          likes:   d.reactions.where(kind: "like").order(created_at: :desc).limit(INLINE_REACTIONS_PER_DELIVERY).map { |r| reaction_payload(r) },
          reposts: d.reactions.where(kind: "repost").order(created_at: :desc).limit(INLINE_REACTIONS_PER_DELIVERY).map { |r| reaction_payload(r) }
        }
      end

      def reply_payload(r)
        {
          id: r.id,
          remote_id: r.remote_id,
          author_handle: r.author_handle,
          author_name: r.author_name,
          author_avatar_url: r.author_avatar_url,
          content: r.content,
          posted_at: r.posted_at&.iso8601,
          permalink: r.permalink
        }
      end

      def reaction_payload(r)
        {
          id: r.id,
          kind: r.kind,
          remote_id: r.remote_id,
          author_handle: r.author_handle,
          author_name: r.author_name,
          author_avatar_url: r.author_avatar_url,
          author_url: r.author_url,
          reacted_at: r.reacted_at&.iso8601,
          observed_at: r.created_at.iso8601
        }
      end

      def enqueue_engagement_sync_if_stale(deliveries)
        deliveries.each do |d|
          next unless d.engagement_syncable? && d.metrics_stale?
          SyncDeliveryEngagementJob.perform_later(d.id)
        end
      end
    end
  end
end
