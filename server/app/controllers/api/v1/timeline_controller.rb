module Api
  module V1
    class TimelineController < BaseController
      def index
        limit = (params[:limit].presence || 50).to_i.clamp(1, 100)
        items = FeedAggregator.new.aggregate(limit: limit, user: current_user)
        render json: { items: items.map { |i| item_payload(i) } }
      end

      def action
        provider = params.require(:provider)
        item_id  = params.require(:id)
        action   = params.require(:action_type)

        ok =
          case provider
          when "mastodon" then mastodon_interact(item_id, action)
          when "bluesky"  then bluesky_interact(item_id, action, params[:cid])
          when "threads"  then threads_interact(item_id, action)
          else
            return render json: { error: "Unsupported provider" }, status: :bad_request
          end

        if ok
          head :ok
        else
          render json: { error: "Provider rejected action" }, status: :unprocessable_entity
        end
      rescue => e
        Rails.logger.error("Timeline action error: #{e.message}")
        render json: { error: e.message }, status: :unprocessable_entity
      end

      private

      def item_payload(item)
        {
          provider: item.provider,
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

      def mastodon_interact(item_id, action)
        pa = current_user.provider_accounts.find_by!(provider: "mastodon")
        conn = Faraday.new(url: pa.instance) { |f| f.adapter Faraday.default_adapter }
        endpoint =
          case action
          when "like"     then "/api/v1/statuses/#{item_id}/favourite"
          when "bookmark" then "/api/v1/statuses/#{item_id}/bookmark"
          when "repost"   then "/api/v1/statuses/#{item_id}/reblog"
          else return false
          end
        resp = conn.post(endpoint) { |r| r.headers["Authorization"] = "Bearer #{pa.access_token}" }
        resp.success?
      end

      def bluesky_interact(item_id, action, cid)
        pa = current_user.provider_accounts.find_by!(provider: "bluesky")
        did, access = Posting::BlueskyClient.new(pa).send(:ensure_session)
        conn = Faraday.new(url: (pa.instance.presence || Posting::BlueskyClient::DEFAULT_BASE)) { |f| f.adapter Faraday.default_adapter }

        subject = { "uri" => item_id }
        subject["cid"] = cid if cid.present?

        collection, type_key =
          case action
          when "like"   then [ "app.bsky.feed.like", "app.bsky.feed.like" ]
          when "repost" then [ "app.bsky.feed.repost", "app.bsky.feed.repost" ]
          else return false
          end

        body = {
          repo: did,
          collection: collection,
          record: { "$type" => type_key, "subject" => subject, "createdAt" => Time.now.utc.iso8601 }
        }
        resp = conn.post("/xrpc/com.atproto.repo.createRecord") do |r|
          r.headers["Authorization"] = "Bearer #{access}"
          r.headers["Content-Type"] = "application/json"
          r.body = JSON.dump(body)
        end
        resp.success?
      end

      def threads_interact(item_id, action)
        pa = current_user.provider_accounts.find_by!(provider: "threads")
        conn = Faraday.new(url: Posting::ThreadsClient::GRAPH_BASE) { |f| f.request :url_encoded; f.adapter Faraday.default_adapter }
        endpoint =
          case action
          when "like"   then "/v1.0/#{item_id}/likes"
          when "repost" then "/v1.0/#{item_id}/reposts"
          else return false
          end
        resp = conn.post(endpoint) { |r| r.body = { access_token: pa.access_token } }
        resp.success?
      end
    end
  end
end
