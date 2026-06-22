module Engagement
  class Syncer
    FETCHERS = {
      "mastodon" => MastodonFetcher,
      "bluesky"  => BlueskyFetcher,
      "threads"  => ThreadsFetcher
    }.freeze

    def initialize(delivery)
      @delivery = delivery
    end

    def call
      return false unless @delivery.engagement_syncable?

      fetcher_class = FETCHERS[@delivery.provider_account.provider]
      return false unless fetcher_class

      result = fetcher_class.new(@delivery).call
      persist!(result)
      true
    rescue => e
      Rails.logger.warn("[Engagement::Syncer] delivery=#{@delivery.id} provider=#{@delivery.provider_account.provider} error: #{e.class}: #{e.message}")
      @delivery.update_columns(
        metrics_error: "#{e.class}: #{e.message}".truncate(500),
        metrics_fetched_at: Time.current
      )
      false
    end

    private

    def persist!(result)
      Delivery.transaction do
        @delivery.update!(
          like_count: result.like_count.to_i,
          reply_count: result.reply_count.to_i,
          repost_count: result.repost_count.to_i,
          metrics_fetched_at: Time.current,
          metrics_error: nil
        )
        upsert_replies(result.replies || [])
      end
    end

    def upsert_replies(replies)
      seen_remote_ids = []
      replies.each do |attrs|
        next if attrs[:remote_id].blank?
        seen_remote_ids << attrs[:remote_id]
        reply = @delivery.replies.find_or_initialize_by(remote_id: attrs[:remote_id])
        reply.assign_attributes(
          author_handle:     attrs[:author_handle],
          author_name:       attrs[:author_name],
          author_avatar_url: attrs[:author_avatar_url],
          content:           attrs[:content],
          posted_at:         attrs[:posted_at],
          permalink:         attrs[:permalink]
        )
        reply.save!
      end
      # Drop replies that have been deleted upstream
      @delivery.replies.where.not(remote_id: seen_remote_ids).delete_all if seen_remote_ids.any?
    end
  end
end
