require "faraday"
require "json"
require "time"

module Engagement
  class ThreadsFetcher
    GRAPH_BASE = ENV.fetch("THREADS_GRAPH_BASE", "https://graph.threads.net")

    def initialize(delivery)
      @delivery = delivery
      @account  = delivery.provider_account
    end

    def call
      token = @account.access_token
      raise "Missing access_token" if token.to_s.strip.empty?
      media_id = @delivery.provider_post_id
      raise "Missing Threads media id" if media_id.to_s.strip.empty?

      app_id = ENV["THREADS_APP_ID"]
      conn = Faraday.new(url: GRAPH_BASE) { |f| f.adapter Faraday.default_adapter }

      counts  = fetch_insights(conn, media_id, token, app_id)
      replies = fetch_replies(conn, media_id, token, app_id)

      Engagement::Result.new(
        like_count:   counts[:likes],
        reply_count:  counts[:replies] || replies.size,
        repost_count: counts[:reposts],
        replies: replies
      )
    end

    private

    def fetch_insights(conn, media_id, token, app_id)
      resp = conn.get("/v1.0/#{media_id}/insights") do |req|
        req.params["metric"] = "likes,replies,reposts,quotes"
        req.params["access_token"] = token
        req.headers["X-IG-App-ID"] = app_id if app_id
        req.headers["Accept"] = "application/json"
        req.options.timeout = 10
        req.options.open_timeout = 5
      end
      raise "Threads insights error: #{resp.status} #{resp.body}" unless resp.success?

      data = (JSON.parse(resp.body)["data"] rescue []) || []
      out = { likes: 0, replies: nil, reposts: 0 }
      data.each do |metric|
        name  = metric["name"]
        value = Array(metric["values"]).first&.dig("value").to_i
        case name
        when "likes"   then out[:likes] = value
        when "replies" then out[:replies] = value
        when "reposts" then out[:reposts] = value
        end
      end
      out
    end

    def fetch_replies(conn, media_id, token, app_id)
      resp = conn.get("/v1.0/#{media_id}/replies") do |req|
        req.params["fields"]       = "id,text,username,timestamp,permalink"
        req.params["access_token"] = token
        req.headers["X-IG-App-ID"] = app_id if app_id
        req.headers["Accept"] = "application/json"
        req.options.timeout = 10
        req.options.open_timeout = 5
      end
      raise "Threads replies error: #{resp.status} #{resp.body}" unless resp.success?

      Array((JSON.parse(resp.body)["data"] rescue []) || []).map do |r|
        {
          remote_id: r["id"].to_s,
          author_handle: r["username"],
          author_name: nil,
          author_avatar_url: nil,
          content: r["text"].to_s,
          posted_at: (Time.parse(r["timestamp"]) rescue nil),
          permalink: r["permalink"]
        }
      end
    end
  end
end
