require "faraday"
require "json"

module Engagement
  class MastodonFetcher
    ACCOUNTS_LIMIT = 40 # mastodon max per page

    def initialize(delivery)
      @delivery = delivery
      @account  = delivery.provider_account
    end

    def call
      base_url = @account.instance.to_s.chomp("/")
      raise "Missing Mastodon instance" if base_url.blank?
      token = @account.access_token
      raise "Missing access_token" if token.blank?

      status_id = @delivery.provider_post_id
      conn = Faraday.new(url: base_url) { |f| f.adapter Faraday.default_adapter }

      status  = get_json!(conn, "/api/v1/statuses/#{status_id}", token)
      context = get_json!(conn, "/api/v1/statuses/#{status_id}/context", token)
      likers_raw   = safe_json(conn, "/api/v1/statuses/#{status_id}/favourited_by?limit=#{ACCOUNTS_LIMIT}", token) || []
      reposters_raw = safe_json(conn, "/api/v1/statuses/#{status_id}/reblogged_by?limit=#{ACCOUNTS_LIMIT}", token) || []

      replies = Array(context["descendants"])
        .select { |s| s["in_reply_to_id"].to_s == status_id.to_s }
        .map { |s| normalize_reply(s) }

      Engagement::Result.new(
        like_count:   status["favourites_count"].to_i,
        reply_count:  status["replies_count"].to_i,
        repost_count: status["reblogs_count"].to_i,
        replies:   replies,
        likers:    likers_raw.map { |a| normalize_account(a) },
        reposters: reposters_raw.map { |a| normalize_account(a) }
      )
    end

    private

    def get_json!(conn, path, token)
      resp = conn.get(path) do |req|
        req.headers["Authorization"] = "Bearer #{token}"
        req.headers["Accept"] = "application/json"
        req.options.timeout = 10
        req.options.open_timeout = 5
      end
      raise "Mastodon GET #{path} error: #{resp.status} #{resp.body}" unless resp.success?
      JSON.parse(resp.body)
    end

    def safe_json(conn, path, token)
      get_json!(conn, path, token)
    rescue => e
      Rails.logger.warn("[Engagement::MastodonFetcher] #{path} failed: #{e.message}")
      nil
    end

    def normalize_reply(status)
      acc = status["account"] || {}
      {
        remote_id: status["id"].to_s,
        author_handle: acc["acct"] || acc["username"],
        author_name: acc["display_name"],
        author_avatar_url: acc["avatar"],
        content: strip_html(status["content"].to_s),
        posted_at: (Time.parse(status["created_at"]) rescue nil),
        permalink: status["url"]
      }
    end

    def normalize_account(acc)
      {
        remote_id: acc["id"].to_s,
        author_handle: acc["acct"] || acc["username"],
        author_name: acc["display_name"].presence,
        author_avatar_url: acc["avatar"],
        author_url: acc["url"],
        reacted_at: nil # Mastodon doesn't expose per-fav timestamps
      }
    end

    def strip_html(html)
      html.gsub(/<br\s*\/?>/i, "\n").gsub(/<\/p>\s*<p[^>]*>/i, "\n\n").gsub(/<[^>]+>/, "").strip
    end
  end
end
