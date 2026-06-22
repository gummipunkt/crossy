require "faraday"
require "json"
require "time"

module Engagement
  class BlueskyFetcher
    DEFAULT_BASE = ENV.fetch("BLUESKY_BASE", "https://bsky.social")

    def initialize(delivery)
      @delivery = delivery
      @account  = delivery.provider_account
    end

    def call
      base_url = (@account.instance.presence || DEFAULT_BASE).chomp("/")
      uri = @delivery.provider_post_id
      raise "Missing AT-URI" if uri.blank?

      _did, access_jwt = refresh_session(base_url)

      conn = Faraday.new(url: base_url) { |f| f.adapter Faraday.default_adapter }
      resp = conn.get("/xrpc/app.bsky.feed.getPostThread") do |req|
        req.params["uri"] = uri
        req.params["depth"] = 1
        req.headers["Authorization"] = "Bearer #{access_jwt}"
        req.headers["Accept"] = "application/json"
        req.options.timeout = 10
        req.options.open_timeout = 5
      end
      raise "Bluesky getPostThread error: #{resp.status} #{resp.body}" unless resp.success?

      thread = (JSON.parse(resp.body)["thread"] || {})
      post = thread["post"] || {}

      replies = Array(thread["replies"]).map { |entry| normalize(entry["post"]) }.compact

      Engagement::Result.new(
        like_count:   post["likeCount"].to_i,
        reply_count:  post["replyCount"].to_i,
        repost_count: post["repostCount"].to_i,
        replies: replies
      )
    end

    private

    def refresh_session(base_url)
      refresh_jwt = @account.refresh_token
      raise "Missing Bluesky refresh token" if refresh_jwt.to_s.strip.empty?

      conn = Faraday.new(url: base_url) { |f| f.adapter Faraday.default_adapter }
      resp = conn.post("/xrpc/com.atproto.server.refreshSession") do |req|
        req.headers["Authorization"] = "Bearer #{refresh_jwt}"
        req.headers["Content-Type"] = "application/json"
        req.options.timeout = 10
        req.options.open_timeout = 5
      end
      raise "Bluesky refresh error: #{resp.status} #{resp.body}" unless resp.success?

      parsed = JSON.parse(resp.body)
      if (new_refresh = parsed["refreshJwt"]).present? && new_refresh != refresh_jwt
        @account.update!(refresh_token: new_refresh)
      end
      [ parsed["did"], parsed["accessJwt"] ]
    end

    def normalize(post)
      return nil unless post
      author = post["author"] || {}
      record = post["record"] || {}
      {
        remote_id: post["uri"].to_s,
        author_handle: author["handle"],
        author_name: author["displayName"],
        author_avatar_url: author["avatar"],
        content: record["text"].to_s,
        posted_at: (Time.parse(record["createdAt"]) rescue nil),
        permalink: bluesky_permalink(author["handle"], post["uri"])
      }
    end

    def bluesky_permalink(handle, uri)
      return nil if handle.blank? || uri.blank?
      rkey = uri.to_s.split("/").last
      "https://bsky.app/profile/#{handle}/post/#{rkey}"
    end
  end
end
