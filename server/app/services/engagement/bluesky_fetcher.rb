require "faraday"
require "json"
require "time"

module Engagement
  class BlueskyFetcher
    DEFAULT_BASE = ENV.fetch("BLUESKY_BASE", "https://bsky.social")
    ACTORS_LIMIT = 100

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

      thread_resp = get_xrpc!(conn, "/xrpc/app.bsky.feed.getPostThread", access_jwt,
                              uri: uri, depth: 1)
      thread = (thread_resp["thread"] || {})
      post = thread["post"] || {}

      replies = Array(thread["replies"]).map { |entry| normalize_reply(entry["post"]) }.compact

      likers_payload    = safe_xrpc(conn, "/xrpc/app.bsky.feed.getLikes",       access_jwt, uri: uri, limit: ACTORS_LIMIT)
      reposters_payload = safe_xrpc(conn, "/xrpc/app.bsky.feed.getRepostedBy", access_jwt, uri: uri, limit: ACTORS_LIMIT)

      likers = Array(likers_payload && likers_payload["likes"]).map { |like|
        normalize_actor(like["actor"], reacted_at: like["createdAt"])
      }.compact
      reposters = Array(reposters_payload && reposters_payload["repostedBy"]).map { |actor|
        normalize_actor(actor)
      }.compact

      Engagement::Result.new(
        like_count:   post["likeCount"].to_i,
        reply_count:  post["replyCount"].to_i,
        repost_count: post["repostCount"].to_i,
        replies:   replies,
        likers:    likers,
        reposters: reposters
      )
    end

    private

    def get_xrpc!(conn, path, access_jwt, **params)
      resp = conn.get(path) do |req|
        params.each { |k, v| req.params[k.to_s] = v }
        req.headers["Authorization"] = "Bearer #{access_jwt}"
        req.headers["Accept"] = "application/json"
        req.options.timeout = 10
        req.options.open_timeout = 5
      end
      raise "Bluesky #{path} error: #{resp.status} #{resp.body}" unless resp.success?
      JSON.parse(resp.body)
    end

    def safe_xrpc(conn, path, access_jwt, **params)
      get_xrpc!(conn, path, access_jwt, **params)
    rescue => e
      Rails.logger.warn("[Engagement::BlueskyFetcher] #{path} failed: #{e.message}")
      nil
    end

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

    def normalize_reply(post)
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
        permalink: bluesky_profile_post_url(author["handle"], post["uri"])
      }
    end

    def normalize_actor(actor, reacted_at: nil)
      return nil unless actor
      {
        remote_id: actor["did"].to_s,
        author_handle: actor["handle"],
        author_name: actor["displayName"].presence,
        author_avatar_url: actor["avatar"],
        author_url: bluesky_profile_url(actor["handle"]),
        reacted_at: (Time.parse(reacted_at) rescue nil)
      }
    end

    def bluesky_profile_post_url(handle, uri)
      return nil if handle.blank? || uri.blank?
      rkey = uri.to_s.split("/").last
      "https://bsky.app/profile/#{handle}/post/#{rkey}"
    end

    def bluesky_profile_url(handle)
      return nil if handle.blank?
      "https://bsky.app/profile/#{handle}"
    end
  end
end
