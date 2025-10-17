require "faraday"
require "json"
require "time"

module Posting
  class BlueskyClient < BaseClient
    DEFAULT_BASE = ENV.fetch("BLUESKY_BASE", "https://bsky.social")

    # First login with app password: saves refreshJwt in provider_accounts.refresh_token
    def login!(password)
      base_url = (@provider_account.instance.presence || DEFAULT_BASE).chomp("/")
      identifier = @provider_account.handle
      raise "Missing handle" if identifier.blank?
      raise "Missing password" if password.to_s.strip.empty?

      conn = Faraday.new(url: base_url) { |f| f.adapter Faraday.default_adapter }
      resp = conn.post("/xrpc/com.atproto.server.createSession") do |req|
        req.headers["Content-Type"] = "application/json"
        req.options.timeout = 10
        req.options.open_timeout = 5
        req.body = JSON.dump({ identifier: identifier, password: password })
      end

      raise "Bluesky login error: #{resp.status} #{resp.body}" unless resp.success?
      parsed = JSON.parse(resp.body) rescue {}
      refresh_jwt = parsed["refreshJwt"] or raise("Missing refreshJwt in response")

      @provider_account.update!(refresh_token: refresh_jwt)
      true
    end

    def post!(post, media_attachments: [])
      did, access_jwt = ensure_session

      base_url = (@provider_account.instance.presence || DEFAULT_BASE).chomp("/")
      conn = Faraday.new(url: base_url) { |f| f.adapter Faraday.default_adapter }

      record = {
        "$type" => "app.bsky.feed.post",
        "text" => post.content_text.to_s,
        "createdAt" => Time.now.utc.iso8601
      }

      # Media (max. 4 Images)
      images = []
      Array(post.media_attachments).first(4).each do |ma|
        next unless ma.file.attached?
        bytes = ma.file.download
        mime = ma.content_type || "application/octet-stream"
        blob = upload_blob!(base_url, access_jwt, bytes, mime)
        images << {
          "alt" => (ma.metadata || {})["alt"].to_s,
          "image" => blob
        }
      end
      if images.any?
        record["embed"] = {
          "$type" => "app.bsky.embed.images",
          "images" => images
        }
      end

      body = {
        repo: did,
        collection: "app.bsky.feed.post",
        record: record
      }

      resp = conn.post("/xrpc/com.atproto.repo.createRecord") do |req|
        req.headers["Authorization"] = "Bearer #{access_jwt}"
        req.headers["Content-Type"] = "application/json"
        req.options.timeout = 15
        req.options.open_timeout = 5
        req.body = JSON.dump(body)
      end

      raise "Bluesky createRecord error: #{resp.status} #{resp.body}" unless resp.success?
      parsed = JSON.parse(resp.body) rescue {}
      parsed["uri"] || raise("Bluesky response missing uri: #{resp.body}")
    end

    private

    def ensure_session
      base_url = (@provider_account.instance.presence || DEFAULT_BASE).chomp("/")
      refresh_jwt = @provider_account.refresh_token
      raise "Missing Bluesky refresh token. Run login! first" if refresh_jwt.to_s.strip.empty?

      conn = Faraday.new(url: base_url) { |f| f.adapter Faraday.default_adapter }
      resp = conn.post("/xrpc/com.atproto.server.refreshSession") do |req|
        req.headers["Authorization"] = "Bearer #{refresh_jwt}"
        req.headers["Content-Type"] = "application/json"
        req.options.timeout = 10
        req.options.open_timeout = 5
      end

      raise "Bluesky refresh error: #{resp.status} #{resp.body}" unless resp.success?
      parsed = JSON.parse(resp.body) rescue {}
      did = parsed["did"] or raise("Missing did in refresh response")
      access = parsed["accessJwt"] or raise("Missing accessJwt in refresh response")
      # Optionally rotate stored refresh token if server returns a new one
      if (new_refresh = parsed["refreshJwt"]).present? && new_refresh != refresh_jwt
        @provider_account.update!(refresh_token: new_refresh)
      end
      [did, access]
    end

    def upload_blob!(base_url, access_jwt, bytes, mime)
      conn = Faraday.new(url: base_url) { |f| f.adapter Faraday.default_adapter }
      resp = conn.post("/xrpc/com.atproto.repo.uploadBlob") do |req|
        req.headers["Authorization"] = "Bearer #{access_jwt}"
        req.headers["Content-Type"] = mime
        req.headers["Accept"] = "application/json"
        req.options.timeout = 15
        req.options.open_timeout = 5
        req.body = bytes
      end
      raise "Bluesky uploadBlob error: #{resp.status} #{resp.body}" unless resp.success?
      parsed = JSON.parse(resp.body) rescue {}
      blob = parsed["blob"]
      # Normalisiere zu { $type:"blob", ref:{"$link":cid}, mimeType, size }
      if blob && !blob["$type"]
        blob["$type"] = "blob"
      end
      blob || raise("uploadBlob response missing blob: #{resp.body}")
    end
  end
end


