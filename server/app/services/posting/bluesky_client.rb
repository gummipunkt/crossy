require "faraday"
require "json"
require "time"

module Posting
  class BlueskyClient < BaseClient
    DEFAULT_BASE = ENV.fetch("BLUESKY_BASE", "https://bsky.social")
    MAX_GRAPHEMES = 300
    MAX_IMAGES = 4
    MAX_IMAGE_BYTES = 1_000_000
    IMAGE_TYPES = %w[image/jpeg image/png image/webp image/gif].freeze

    # First login with app password: saves refreshJwt in provider_accounts.refresh_token
    def login!(password)
      base_url = (@provider_account.instance.presence || DEFAULT_BASE).chomp("/")
      identifier = @provider_account.handle
      raise "Missing handle" if identifier.blank?
      raise "Missing password" if password.to_s.strip.empty?

      conn = SafeHttp.connection(base_url)
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

    def post!(post, media_attachments: [], idempotency_key: nil)
      text = post.content_text.to_s
      if text.grapheme_clusters.length > MAX_GRAPHEMES
        raise "Bluesky posts are limited to #{MAX_GRAPHEMES} characters (this one has #{text.grapheme_clusters.length})"
      end
      attachments = Array(post.media_attachments).select { |ma| ma.file.attached? }
      validate_images!(attachments)

      did, access_jwt = session!

      base_url = (@provider_account.instance.presence || DEFAULT_BASE).chomp("/")
      conn = SafeHttp.connection(base_url)

      record = {
        "$type" => "app.bsky.feed.post",
        "text" => text,
        "createdAt" => Time.now.utc.iso8601
      }
      facets = BlueskyFacets.build(text, resolve_handle: ->(handle) { resolve_handle(conn, access_jwt, handle) })
      record["facets"] = facets if facets.any?

      images = attachments.map do |ma|
        blob = upload_blob!(base_url, access_jwt, ma.file.download, ma.content_type)
        { "alt" => (ma.metadata || {})["alt"].to_s, "image" => blob }
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

    # Refreshes the session and returns [did, accessJwt].
    def session!
      base_url = (@provider_account.instance.presence || DEFAULT_BASE).chomp("/")
      refresh_jwt = @provider_account.refresh_token
      raise "Missing Bluesky refresh token. Run login! first" if refresh_jwt.to_s.strip.empty?

      conn = SafeHttp.connection(base_url)
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
      [ did, access ]
    end

    private

    # Fail with a clear message instead of a generic createRecord/uploadBlob error.
    def validate_images!(attachments)
      raise "Bluesky allows at most #{MAX_IMAGES} images" if attachments.size > MAX_IMAGES

      attachments.each do |ma|
        unless IMAGE_TYPES.include?(ma.content_type)
          raise "Bluesky: #{ma.filename} (#{ma.content_type}) is not supported, only JPEG, PNG, WebP and GIF images"
        end
        if ma.file.byte_size > MAX_IMAGE_BYTES
          raise "Bluesky: #{ma.filename} is #{ma.file.byte_size / 1000} KB, the limit is #{MAX_IMAGE_BYTES / 1000} KB"
        end
      end
    end

    def resolve_handle(conn, access_jwt, handle)
      resp = conn.get("/xrpc/com.atproto.identity.resolveHandle") do |req|
        req.params["handle"] = handle
        req.headers["Authorization"] = "Bearer #{access_jwt}"
        req.headers["Accept"] = "application/json"
        req.options.timeout = 5
        req.options.open_timeout = 5
      end
      resp.success? ? (JSON.parse(resp.body) rescue {})["did"] : nil
    rescue Faraday::Error
      nil
    end

    def upload_blob!(base_url, access_jwt, bytes, mime)
      conn = SafeHttp.connection(base_url)
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
