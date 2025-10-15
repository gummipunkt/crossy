require "faraday"
require "faraday/multipart"
require "json"
require "uri"

module Posting
  class MastodonClient < BaseClient
    def post!(post, media_attachments: [])
      base_url = @provider_account.instance.chomp("/")
      token = @provider_account.access_token
      raise "Missing access_token" if token.blank?

      body = { status: post.content_text }
      if post.content_warning.present?
        body[:spoiler_text] = post.content_warning.to_s
      end

      media_ids = []
      Array(post.media_attachments).each do |ma|
        next unless ma.file.attached?
        io = ma.file.download
        up = Faraday::Multipart::FilePart.new(StringIO.new(io), ma.content_type, ma.filename)
        upload_conn = Faraday.new(url: base_url) do |f|
          f.request :multipart
          f.request :url_encoded
          f.adapter Faraday.default_adapter
        end
        up_resp = upload_conn.post("/api/v2/media") do |req|
          req.headers["Authorization"] = "Bearer #{token}"
          req.headers["Accept"] = "application/json"
          req.body = { file: up, description: (ma.metadata || {})["alt"].to_s }
        end
        raise "Mastodon media error: #{up_resp.status} #{up_resp.body}" unless up_resp.success?
        media_json = JSON.parse(up_resp.body) rescue {}
        media_ids << media_json["id"] if media_json["id"]
      end
      body[:media_ids] = media_ids if media_ids.any?
      # TODO: Medien-Upload später ergänzen

      conn = Faraday.new(url: base_url) do |f|
        f.request :url_encoded
        f.adapter Faraday.default_adapter
      end

      resp = conn.post("/api/v1/statuses") do |req|
        req.headers["Authorization"] = "Bearer #{token}"
        req.headers["Accept"] = "application/json"
        req.options.timeout = 15
        req.options.open_timeout = 5
        req.body = body
      end

      unless resp.success?
        raise "Mastodon error: #{resp.status} #{resp.body}"
      end

      parsed = JSON.parse(resp.body) rescue {}
      parsed["id"] || raise("Mastodon response missing id: #{resp.body}")
    end
  end
end
