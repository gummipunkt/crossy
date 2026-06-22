require "faraday"
require "json"

module Engagement
  class MastodonFetcher
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

      status = get_json!(conn, "/api/v1/statuses/#{status_id}", token)
      context = get_json!(conn, "/api/v1/statuses/#{status_id}/context", token)

      replies = Array(context["descendants"])
        .select { |s| s["in_reply_to_id"].to_s == status_id.to_s }
        .map { |s| normalize(s) }

      Engagement::Result.new(
        like_count:   status["favourites_count"].to_i,
        reply_count:  status["replies_count"].to_i,
        repost_count: status["reblogs_count"].to_i,
        replies: replies
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

    def normalize(status)
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

    def strip_html(html)
      html.gsub(/<br\s*\/?>/i, "\n").gsub(/<\/p>\s*<p[^>]*>/i, "\n\n").gsub(/<[^>]+>/, "").strip
    end
  end
end
