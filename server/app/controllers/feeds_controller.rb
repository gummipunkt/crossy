class FeedsController < ApplicationController
  def index
    @items = FeedAggregator.new.aggregate(limit: 50, user: current_user)
  end

  def interact
    provider = params.require(:provider)
    item_id  = params.require(:id)
    action   = params.require(:action_type)

    case provider
    when "mastodon"
      mastodon_interact(item_id, action)
    when "bluesky"
      bluesky_interact(item_id, action, params[:cid])
    when "threads"
      threads_interact(item_id, action)
    else
      head :bad_request
    end
  rescue => _e
    head :unprocessable_entity
  end

  private

  def mastodon_interact(item_id, action)
    pa = current_user.provider_accounts.find_by!(provider: "mastodon")
    conn = Faraday.new(url: pa.instance) { |f| f.adapter Faraday.default_adapter }
    endpoint =
      case action
      when "like"     then "/api/v1/statuses/#{item_id}/favourite"
      when "bookmark" then "/api/v1/statuses/#{item_id}/bookmark"
      when "repost"   then "/api/v1/statuses/#{item_id}/reblog"
      else raise ActionController::BadRequest, "unsupported action"
      end
    resp = conn.post(endpoint) { |r| r.headers["Authorization"] = "Bearer #{pa.access_token}" }
    head(resp.success? ? :ok : :unprocessable_entity)
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
      else raise ActionController::BadRequest, "unsupported action"
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
    head(resp.success? ? :ok : :unprocessable_entity)
  end

  def threads_interact(item_id, action)
    pa = current_user.provider_accounts.find_by!(provider: "threads")
    conn = Faraday.new(url: Posting::ThreadsClient::GRAPH_BASE) { |f| f.request :url_encoded; f.adapter Faraday.default_adapter }
    endpoint =
      case action
      when "like"   then "/v1.0/#{item_id}/likes"
      when "repost" then "/v1.0/#{item_id}/reposts"
      else raise ActionController::BadRequest, "unsupported action"
      end
    resp = conn.post(endpoint) { |r| r.body = { access_token: pa.access_token } }
    head(resp.success? ? :ok : :unprocessable_entity)
  end
end
