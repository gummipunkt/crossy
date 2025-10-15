class FeedsController < ApplicationController
  skip_before_action :verify_authenticity_token, only: :interact
  def index
    @items = FeedAggregator.new.aggregate(limit: 50, user: current_user)
  end

  def interact
    provider = params.require(:provider)
    item_id  = params.require(:id)
    action   = params.require(:action_type) # like|repost

    case provider
    when "mastodon"
      pa = ProviderAccount.where(provider: "mastodon", user_id: current_user.id).first
      raise "Kein Mastodon-Kanal" unless pa
      conn = Faraday.new(url: pa.instance) { |f| f.adapter Faraday.default_adapter }
      endpoint = action == "like" ? "/api/v1/statuses/#{item_id}/favourite" : "/api/v1/statuses/#{item_id}/reblog"
      resp = conn.post(endpoint) { |r| r.headers["Authorization"] = "Bearer #{pa.access_token}" }
      head(resp.success? ? :ok : :unprocessable_entity)

    when "bluesky"
      pa = ProviderAccount.where(provider: "bluesky", user_id: current_user.id).first
      raise "Kein Bluesky-Kanal" unless pa
      did, access = Posting::BlueskyClient.new(pa).send(:ensure_session)
      conn = Faraday.new(url: (pa.instance.presence || Posting::BlueskyClient::DEFAULT_BASE)) { |f| f.adapter Faraday.default_adapter }
      if action == "like"
        body = { repo: did, collection: "app.bsky.feed.like", record: { "$type"=>"app.bsky.feed.like", "subject"=>{ "uri"=>item_id }, "createdAt"=>Time.now.utc.iso8601 } }
      else
        body = { repo: did, collection: "app.bsky.feed.repost", record: { "$type"=>"app.bsky.feed.repost", "subject"=>{ "uri"=>item_id }, "createdAt"=>Time.now.utc.iso8601 } }
      end
      resp = conn.post("/xrpc/com.atproto.repo.createRecord") { |r| r.headers["Authorization"] = "Bearer #{access}"; r.headers["Content-Type"] = "application/json"; r.body = JSON.dump(body) }
      head(resp.success? ? :ok : :unprocessable_entity)

    when "threads"
      pa = ProviderAccount.where(provider: "threads", user_id: current_user.id).first
      raise "Kein Threads-Kanal" unless pa
      conn = Faraday.new(url: Posting::ThreadsClient::GRAPH_BASE) { |f| f.request :url_encoded; f.adapter Faraday.default_adapter }
      endpoint = action == "like" ? "/v1.0/#{item_id}/likes" : "/v1.0/#{item_id}/reposts"
      resp = conn.post(endpoint) { |r| r.body = { access_token: pa.access_token } }
      head(resp.success? ? :ok : :unprocessable_entity)

    else
      head :bad_request
    end
  rescue => _e
    head :unprocessable_entity
  end
end


